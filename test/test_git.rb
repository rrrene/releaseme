require 'fileutils'

require_relative 'lib/testme'

require_relative '../lib/git'

module Silencer
  module_function

  def run(cmd)
    `#{cmd} 2>&1`
  end
end

class TestGit < Testme
  attr_reader :remotedir

  def `(other)
    Silencer.run(other)
  end

  def setup_repo_content
    `git clone #{@remotedir} clone`
    Dir.chdir('clone') do
      File.write('abc', 'content')
      `git add abc`
      `git commit -a -m 'import'`
      `git push origin master`
    end
  ensure
    FileUtils.rm_rf('clone')
  end

  def setup
    # Create a test remote
    Dir.mkdir('remote')
    Dir.chdir('remote') do
      `git init --bare .`
    end
    @remotedir = "#{Dir.pwd}/remote"

    setup_repo_content

    # Teardown happens automatically when the @tmpdir is torn down
  end

  def test_init
    g = Git.new
    assert_not_nil(g)
    g.repository = '/repo'
    assert_equal('/repo', g.repository)
    assert_nil(g.branch)
    g.branch = 'brunch'
    assert_equal('/repo', g.repository)
    assert_equal('brunch', g.branch)
    assert_nil(g.hash)
  end

  def test_get
    g = Git.new
    g.repository = @remotedir
    g.get('clone')
    assert(File.exist?('clone/abc'))
    assert_equal('content', File.read('clone/abc'))
    assert_not_nil(g.hash)
  end

  def test_clean
    g = Git.new
    g.repository = @remotedir
    g.get('clone')
    assert(File.exist?('clone/.git'))
    g.clean!('clone')
    assert(!File.exist?('clone/.git'))
  end

  def create_from_hash
    Git.from_hash('repository' => '/kitten', 'branch' => 'brunch')
  end

  def test_from_hash
    g = create_from_hash
    assert_not_nil(g)
    assert_equal('/kitten', g.repository)
    assert_equal('brunch', g.branch)
  end

  def test_to_s
    g = create_from_hash
    assert_equal('(git - /kitten [brunch])', g.to_s)
  end
end
