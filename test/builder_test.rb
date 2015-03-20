require_relative 'test_helper'

class BuilderTest < MiniTest::Test

  def setup
    @options = {
      :username => nil,
      :password => '',
      :smt_host => nil,
      :disable_https => false,
      :include_build_repositories => true
    }

    @template_file = File.join(Sle2Docker::Template.kiwi_template_dir("SLE11SP3"),
                              "config.xml.erb")
  end


  # testing render_template

  def test_render_template_ncc_nothing_set
    expected = read_fixture("sle11sp3_config.xml")
    password = "fake password"
    username = "test_user"

    builder = Sle2Docker::Builder.new(@options)

    $stdin = FakeStdin.new([username, password])

    template = ""
    stdout = capture(:stdout) do
      template = builder.render_template(@template_file)
    end

    assert_equal(expected, template)
    stdout_expected_sequence = ["Enter NCC username:", "Enter NCC password:"]
    assert_equal(stdout.split("\n"), stdout_expected_sequence)
  end

  def test_render_template_ncc_username_set
    expected            = read_fixture("sle11sp3_config.xml")
    password            = "fake password"
    @options[:username] = "test_user"

    builder = Sle2Docker::Builder.new(@options)

    $stdin = FakeStdin.new([password])

    template = ""
    stdout = capture(:stdout) do
      template = builder.render_template(@template_file)
    end

    assert_equal(expected, template)
    assert_equal("Enter NCC password:", stdout.chomp)
  end

  def test_render_template_ncc_username_and_password_set
    expected            = read_fixture("sle11sp3_config.xml")
    @options[:password] = "fake password"
    @options[:username] = "test_user"

    builder = Sle2Docker::Builder.new(@options)

    template = ""
    stdout = capture(:stdout) do
      template = STDIN.stub(:gets, RuntimeError.new("Not expected!")) do
        builder.render_template(@template_file)
      end
    end

    assert_equal(expected, template)
    assert stdout.empty?
  end

  def test_render_template_smt_no_auth
    expected            = read_fixture("sle11sp3_smt_no_auth_https_config.xml")
    @options[:smt_host] = "my_smt.local"

    builder = Sle2Docker::Builder.new(@options)

    template = ""
    stdout = capture(:stdout) do
      template = STDIN.stub(:gets, RuntimeError.new("Not expected!")) do
        builder.render_template(@template_file)
      end
    end

    assert_equal(expected, template)
    assert stdout.empty?
  end

  def test_render_template_smt_no_auth_disable_https
    expected                 = read_fixture("sle11sp3_smt_no_auth_no_https_config.xml")
    @options[:smt_host]      = "my_smt.local"
    @options[:disable_https] = true

    builder = Sle2Docker::Builder.new(@options)

    template = ""
    stdout = capture(:stdout) do
      template = STDIN.stub(:gets, RuntimeError.new("Not expected!")) do
        builder.render_template(@template_file)
      end
    end

    assert_equal(expected, template)
    assert stdout.empty?
  end

  def test_render_template_smt_username_set
    expected                 = read_fixture("sle11sp3_smt_auth_config.xml")
    @options[:smt_host]      = "my_smt.local"
    @options[:disable_https] = true
    @options[:username]      = "test_user"
    password                 = "fake password"

    builder = Sle2Docker::Builder.new(@options)

    $stdin = FakeStdin.new([password])

    template = ""
    stdout = capture(:stdout) do
      template = builder.render_template(@template_file)
    end

    assert_equal(expected, template)
    assert_equal("Enter password:", stdout.chomp)
  end

  def test_render_template_smt_password_set
    expected                 = read_fixture("sle11sp3_smt_auth_config.xml")
    @options[:smt_host]      = "my_smt.local"
    @options[:disable_https] = true
    @options[:password]      = "fake password"
    username                 = "test_user"

    builder = Sle2Docker::Builder.new(@options)

    $stdin = FakeStdin.new([username])

    template = ""
    stdout = capture(:stdout) do
      template = builder.render_template(@template_file)
    end

    assert_equal(expected, template)
    assert_equal("Enter username:", stdout.chomp)
  end

  # Testing find_template_file

  def test_find_template_file
    template = Sle2Docker::Template.list_kiwi.first
    template_dir = Sle2Docker::Template.kiwi_template_dir(template)
    builder = Sle2Docker::Builder.new(@options)

    actual = builder.find_template_file(template_dir)
    assert File.exist?(actual)
  end

  def test_find_template_file_raises_exception_on_missing_file
    builder = Sle2Docker::Builder.new(@options)

    assert_raises(Sle2Docker::ConfigNotFoundError) do
      builder.find_template_file("/tmp")
    end
  end

  # Testing parsing of resolv.conf

  def test_parse_resolv_conf
    actual = []
    expected = %w(1 2 3)

    FakeFS do
      FileUtils.mkdir("/etc")
      File.open("/etc/resolv.conf", 'w') do |file|
        file.write("nameserver 1\n")
        file.write("nameserver  2\n")
        file.write("nameserver\t\t3\n")
        file.write("# nameserver ignored")
      end
      builder = Sle2Docker::Builder.new(@options)
      actual = builder.dns_entries()
    end

    assert_equal(expected, actual)
  end
end

