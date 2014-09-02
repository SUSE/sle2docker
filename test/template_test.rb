require_relative 'test_helper'

class TemplateTest < MiniTest::Test

  def test_list
    actual = Sle2Docker::Template.list
    expected = ['SLE11SP2', 'SLE11SP3', 'SLE12']
    assert_equal expected.sort, actual.sort
  end

  def test_complain_when_requested_template_does_not_exist
    assert_raises(Sle2Docker::TemplateNotFoundError)do
      Sle2Docker::Template.template_dir("foo")
    end
  end

  def test_find_existing_template
    dir = Sle2Docker::Template.template_dir(Sle2Docker::Template.list.first)
    assert File.exist?(dir)
  end

  def test_find_should_be_case_insensitive
    dir = Sle2Docker::Template.template_dir(
      Sle2Docker::Template.list.first.downcase)
    assert File.exist?(dir)
  end


end

