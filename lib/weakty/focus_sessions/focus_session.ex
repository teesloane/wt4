defmodule Weakty.FocusSessions.FocusSession do
  use Ash.Resource,
    domain: Weakty.FocusSessions,
    data_layer: AshSqlite.DataLayer,
    extensions: [AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer]

  sqlite do
    table "focus_sessions"
    repo Weakty.Repo
  end

  code_interface do
    define :create_session, action: :create
    define :start_break, action: :start_break
    define :complete_break, action: :complete_break
    define :abandon_session, action: :abandon
    define :update_notes, action: :update_notes
    define :delete_session, action: :destroy
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title,
        :category,
        :notes,
        :duration_minutes,
        :break_duration_minutes,
        :project_id,
        :user_id,
        :status,
        :started_at
      ]
    end

    update :start_break do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :on_break)
        |> Ash.Changeset.force_change_attribute(:break_started_at, DateTime.utc_now())
      end
    end

    update :complete_break do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:status, :completed)
        |> Ash.Changeset.force_change_attribute(:completed_at, DateTime.utc_now())
      end
    end

    update :abandon do
      accept []
      require_atomic? false

      change fn changeset, _context ->
        started_at = Ash.Changeset.get_attribute(changeset, :started_at) ||
          changeset.data.started_at

        elapsed =
          if started_at do
            max(0, DateTime.diff(DateTime.utc_now(), started_at, :second) |> div(60))
          else
            0
          end

        changeset
        |> Ash.Changeset.force_change_attribute(:status, :abandoned)
        |> Ash.Changeset.force_change_attribute(:elapsed_minutes, elapsed)
      end
    end

    update :update_notes do
      accept [:notes]
    end
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :category, :string do
      public? true
    end

    attribute :notes, :string do
      public? true
    end

    attribute :duration_minutes, :integer do
      allow_nil? false
      default 25
      public? true
    end

    attribute :break_duration_minutes, :integer do
      allow_nil? false
      default 5
      public? true
    end

    attribute :status, :atom do
      allow_nil? false
      default :idle
      public? true
      constraints one_of: [:idle, :active, :on_break, :completed, :abandoned]
    end

    attribute :elapsed_minutes, :integer do
      public? true
    end

    attribute :started_at, :utc_datetime_usec do
      public? true
    end

    attribute :break_started_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Weakty.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :project, Weakty.Projects.Project do
      allow_nil? true
      attribute_writable? true
    end
  end
end
