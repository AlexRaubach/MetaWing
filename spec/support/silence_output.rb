# The importers report progress with puts/print/warn. Tag a group with
# `:silence_output` to keep that out of the spec run.
RSpec.configure do |config|
  config.around(:each, :silence_output) do |example|
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    begin
      example.run
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end
  end
end
