defmodule Munchkin.Inventory.Fundamental.General do
  use Ecto.Schema

  defstruct [
    :period,
    :partner_name,
    :review_engagement,
    :last_period_start_date,
    :last_period_end_date,
    :type,
    :comply_with_capital,
    :partner_experience,
    :auditor_type,
    :fundamental_type,
    :audit_matters,
    :current_year_audit,
    :date_of_audit,
    :industry,
    :subindustry,
    :code,
    :company_type,
    :disclosed_matter,
    :audit_descriptions,
    :shareholder_informations,
    :name,
    :general_information,
    :last_year_start_date,
    :last_year_end_date,
    :last_year_auditor_name,
    :accounting_standards,
    :total_audit_matters,
    :last_two_year_end_date,
    :sector,
    :subsector,
    :currency,
    :listed_securities,
    :report_type,
    :main_industry,
    :name_changed,
    :rounding,
    :comply_with_bod,
    :conversion_rate,
    :last_year_auditor_date,
    :board,
    :current_start_date,
    :current_end_date,
    :entity_type,
    :filling_date,
    :identification_number
  ]

  @type t :: %__MODULE__{
          period: String.t(),
          partner_name: String.t(),
          review_engagement: String.t(),
          last_period_start_date: String.t(),
          last_period_end_date: String.t(),
          type: String.t(),
          comply_with_capital: String.t(),
          partner_experience: String.t(),
          auditor_type: String.t(),
          fundamental_type: String.t(),
          audit_matters: String.t(),
          current_year_audit: String.t(),
          date_of_audit: String.t(),
          industry: String.t(),
          subindustry: String.t(),
          code: String.t(),
          company_type: String.t(),
          disclosed_matter: String.t(),
          audit_descriptions: String.t(),
          shareholder_informations: String.t(),
          name: String.t(),
          general_information: String.t(),
          last_year_start_date: String.t(),
          last_year_end_date: String.t(),
          last_year_auditor_name: String.t(),
          accounting_standards: String.t(),
          total_audit_matters: String.t(),
          last_two_year_end_date: String.t(),
          sector: String.t(),
          subsector: String.t(),
          currency: String.t(),
          listed_securities: String.t(),
          report_type: String.t(),
          main_industry: String.t(),
          name_changed: String.t(),
          rounding: String.t(),
          comply_with_bod: String.t(),
          conversion_rate: String.t(),
          last_year_auditor_date: String.t(),
          board: String.t(),
          current_start_date: String.t(),
          current_end_date: String.t(),
          entity_type: String.t(),
          filling_date: String.t(),
          identification_number: String.t()
        }

  defimpl Inspect, for: __MODULE__ do
    def inspect(%_mod{name: name, code: code, period: period}, _opts) do
      "#General<ticker: #{code}, name: #{name}, period: #{period}, rest: ...>"
    end
  end

  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(value, opts) do
      Map.from_struct(value)
      |> Jason.Encode.map(opts)
    end
  end
end
