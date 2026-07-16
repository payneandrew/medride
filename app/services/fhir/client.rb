require "fhir_client"

module Fhir
  # Thin wrapper around fhir-crucible's fhir_client gem, which does the
  # heavy lifting a real integration needs: typed R4 resources
  # (FHIR::Patient, FHIR::Bundle, ...), content negotiation, and resource
  # validation. We still translate everything into our own plain
  # Fhir::Patient/Fhir::Appointment structs (see patient.rb, appointment.rb)
  # rather than passing FHIR::Model objects deeper into the app — that keeps
  # the rest of medride from depending on the gem's object model, and keeps
  # the FHIR field-mapping decisions in one place.
  class Client
    class Error < StandardError; end

    BASE_URL = ENV.fetch("FHIR_BASE_URL", "https://hapi.fhir.org/baseR4")

    def initialize(connection: self.class.build_connection)
      @connection = connection
    end

    def fetch_patient(id)
      reply = @connection.read(FHIR::Patient, id)
      return nil if reply.code.to_i == 404

      raise_unless_success!(reply)
      parse_patient(reply.resource)
    end

    def search_patients(family_name)
      reply = @connection.search(FHIR::Patient, search: { parameters: { family: family_name } })
      raise_unless_success!(reply)
      resources_from_bundle(reply.resource).map { |resource| parse_patient(resource) }
    end

    def fetch_appointments(patient_id)
      reply = @connection.search(FHIR::Appointment, search: { parameters: { patient: patient_id, status: "booked" } })
      raise_unless_success!(reply)
      resources_from_bundle(reply.resource).map { |resource| parse_appointment(resource) }
    end

    def self.build_connection
      client = FHIR::Client.new(BASE_URL)
      client.default_format = "application/fhir+json"
      client.use_r4
      client
    end

    private

    def raise_unless_success!(reply)
      return if reply.code.to_i.between?(200, 299)

      raise Error, "FHIR server responded #{reply.code} for #{reply.request[:url]}"
    end

    # FHIR::Client returns nil (not a raised error) for a 404 read; treat a
    # missing resource as "no patient" rather than an error.
    def resources_from_bundle(bundle)
      return [] if bundle.nil?

      Array(bundle.entry).map(&:resource)
    end

    def parse_patient(resource)
      return nil if resource.nil?

      name = Array(resource.name).first
      address = Array(resource.address).first
      phone = Array(resource.telecom).find { |t| t.system == "phone" }

      Fhir::Patient.new(
        fhir_id: resource.id,
        given_name: name && Array(name.given).first,
        family_name: name&.family,
        phone: phone&.value,
        birth_date: resource.birthDate,
        address_line1: address && Array(address.line).first,
        city: address&.city,
        state: address&.state,
        postal_code: address&.postalCode
      )
    end

    def parse_appointment(resource)
      Fhir::Appointment.new(
        fhir_id: resource.id,
        status: resource.status,
        start_time: resource.start && Time.iso8601(resource.start),
        description: resource.description,
        patient_fhir_id: patient_reference(resource)
      )
    end

    # participant[].actor.reference looks like "Patient/137019620" — this is
    # also where, in a real integration, you'd have to reconcile that the
    # *system* on Patient.identifier (an MRN, not this bare numeric FHIR id)
    # is the durable key you actually want to store and match on, since FHIR
    # resource ids are only guaranteed unique per-server, not portable across
    # EHR instances.
    def patient_reference(resource)
      participant = Array(resource.participant).find do |p|
        p.actor&.reference.to_s.start_with?("Patient/")
      end
      participant&.actor&.reference&.delete_prefix("Patient/")
    end
  end
end
