require "test_helper"

class SmartOnFhir::ConfigurationTest < ActiveSupport::TestCase
  test "discovers the authorization and token endpoints from the well-known document" do
    stub_request(:get, "https://r4.smarthealthit.org/.well-known/smart-configuration")
      .to_return(
        status: 200,
        body: {
          authorization_endpoint: "https://launch.smarthealthit.org/v/r4/auth/authorize",
          token_endpoint: "https://launch.smarthealthit.org/v/r4/auth/token"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = SmartOnFhir::Configuration.discover("https://r4.smarthealthit.org")

    assert_equal "https://launch.smarthealthit.org/v/r4/auth/authorize", result.authorization_endpoint
    assert_equal "https://launch.smarthealthit.org/v/r4/auth/token", result.token_endpoint
  end

  test "strips a trailing slash on iss before building the well-known URL" do
    stub_request(:get, "https://r4.smarthealthit.org/.well-known/smart-configuration")
      .to_return(
        status: 200,
        body: { authorization_endpoint: "https://a", token_endpoint: "https://b" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_nothing_raised { SmartOnFhir::Configuration.discover("https://r4.smarthealthit.org/") }
  end

  test "raises on a non-2xx response" do
    stub_request(:get, "https://r4.smarthealthit.org/.well-known/smart-configuration")
      .to_return(status: 404, body: "not found")

    assert_raises(SmartOnFhir::Configuration::Error) do
      SmartOnFhir::Configuration.discover("https://r4.smarthealthit.org")
    end
  end

  test "raises on a malformed document missing required fields" do
    stub_request(:get, "https://r4.smarthealthit.org/.well-known/smart-configuration")
      .to_return(status: 200, body: { authorization_endpoint: "https://a" }.to_json,
        headers: { "Content-Type" => "application/json" })

    assert_raises(SmartOnFhir::Configuration::Error) do
      SmartOnFhir::Configuration.discover("https://r4.smarthealthit.org")
    end
  end
end
