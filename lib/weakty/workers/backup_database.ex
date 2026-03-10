defmodule Weakty.Workers.BackupDatabase do
  use Oban.Worker, queue: :default
  require Logger

  # Number of backup files to keep
  @keep 7

  @impl true
  def perform(_job) do
    db_path = Application.get_env(:weakty, Weakty.Repo)[:database]
    backup_dir = backup_dir()
    File.mkdir_p!(backup_dir)

    timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M%S")
    dest = Path.join(backup_dir, "weakty_#{timestamp}.db")

    {:ok, conn} = Exqlite.Sqlite3.open(db_path)

    try do
      {:ok, binary} = Exqlite.Sqlite3.serialize(conn, "main")
      File.write!(dest, binary)
      Logger.info("[BackupDatabase] Wrote #{byte_size(binary)} bytes to #{dest}")
    after
      Exqlite.Sqlite3.close(conn)
    end

    prune_old_backups(backup_dir)

    :ok
  end

  def backup_dir do
    Path.join(:code.priv_dir(:weakty), "backups")
  end

  def list_backups do
    dir = backup_dir()

    if File.exists?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".db"))
      |> Enum.sort(:desc)
      |> Enum.map(fn name ->
        path = Path.join(dir, name)
        %{name: name, path: path, size: File.stat!(path).size}
      end)
    else
      []
    end
  end

  defp prune_old_backups(dir) do
    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".db"))
    |> Enum.sort(:desc)
    |> Enum.drop(@keep)
    |> Enum.each(fn name ->
      File.rm!(Path.join(dir, name))
      Logger.info("[BackupDatabase] Pruned old backup: #{name}")
    end)
  end
end
