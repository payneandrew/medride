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
  end
end
