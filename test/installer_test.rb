# frozen_string_literal: true

require "test_helper"
require "installer"

class InstallerTest < DotfilesTestCase
  def setup
    super
    @output = StringIO.new
    @installer = Installer.new(output: @output)
  end

  def test_installer_responds_to_install
    assert_respond_to @installer, :install
  end

  def test_installer_responds_to_link_dotfiles
    assert_respond_to @installer, :link_dotfiles
  end

  def test_installer_responds_to_install_brew_packages
    assert_respond_to @installer, :install_brew_packages
  end

  def test_link_dotfiles_outputs_header
    @installer.link_dotfiles
    assert_match(/Linking dotfiles/, @output.string)
  end
end
