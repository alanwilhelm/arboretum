defmodule Arboretum.Repo do
  use Ecto.Repo,
    otp_app: :arboretum,
    adapter: Ecto.Adapters.Postgres
end
