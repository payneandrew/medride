module Fhir
  # A hand-rolled projection of the fields we care about from a FHIR R4
  # Patient resource. Deliberately flat and plain-Ruby (not an ActiveRecord
  # model, not a full FHIR resource object) — it's the seam between "what the
  # HAPI server sent us" and "what our own Patient model needs."
  Patient = Struct.new(
    :fhir_id, :given_name, :family_name, :phone, :birth_date,
    :address_line1, :city, :state, :postal_code,
    keyword_init: true
  ) do
    def full_name
      [ given_name, family_name ].compact.join(" ")
    end

    # Whether this record has enough demographic info to import — the
    # public HAPI test server has plenty of name-only records, and
    # EhrImportsController#create rejects those outright (see the comment
    # there). Surfacing this in the search results, before a coordinator
    # clicks Import, is better than letting them find out after.
    REQUIRED_FIELDS = {
      given_name: "given name", family_name: "family name", phone: "phone",
      address_line1: "address", city: "city", state: "state", postal_code: "zip"
    }.freeze

    def importable?
      missing_fields.empty?
    end

    def missing_fields
      REQUIRED_FIELDS.filter_map { |attr, label| label if send(attr).blank? }
    end
  end
end
