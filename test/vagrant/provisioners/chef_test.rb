require File.join(File.dirname(__FILE__), '..', '..', 'test_helper')

class ChefProvisionerTest < Test::Unit::TestCase
  setup do
    @env = mock_environment
    @action = Vagrant::Provisioners::Chef.new(@env)

    Vagrant::SSH.stubs(:execute)
    Vagrant::SSH.stubs(:upload!)

    mock_config
  end

  context "preparing" do
    should "raise an ActionException" do
      assert_raises(Vagrant::Actions::ActionException) {
        @action.prepare
      }
    end
  end

  context "config" do
    setup do
      @config = Vagrant::Provisioners::Chef::ChefConfig.new
      @config.run_list.clear
    end

    should "not include the 'json' key in the config dump" do
      result = JSON.parse(@config.to_json)
      assert !result.has_key?("json")
    end

    should "provide accessors to the run list" do
      @config.run_list << "foo"
      assert !@config.run_list.empty?
      assert_equal ["foo"], @config.run_list
    end

    should "provide a writer for the run list" do
      data = mock("data")

      assert_nothing_raised {
        @config.run_list = data
        assert_equal data, @config.run_list
      }
    end

    should "add a recipe to the run list" do
      @config.add_recipe("foo")
      assert_equal "recipe[foo]", @config.run_list[0]
    end

    should "not wrap the recipe in 'recipe[]' if it was in the name" do
      @config.add_recipe("recipe[foo]")
      assert_equal "recipe[foo]", @config.run_list[0]
    end

    should "add a role to the run list" do
      @config.add_role("user")
      assert_equal "role[user]", @config.run_list[0]
    end

    should "not wrap the role in 'role[]' if it was in the name" do
      @config.add_role("role[user]")
      assert_equal "role[user]", @config.run_list[0]
    end
  end

  context "permissions on provisioning folder" do
    should "create and chown the folder to the ssh user" do
      ssh_seq = sequence("ssh_seq")
      ssh = mock("ssh")
      ssh.expects(:exec!).with("sudo mkdir -p #{@env.config.chef.provisioning_path}").once.in_sequence(ssh_seq)
      ssh.expects(:exec!).with("sudo chown #{@env.config.ssh.username} #{@env.config.chef.provisioning_path}").once.in_sequence(ssh_seq)
      @env.ssh.expects(:execute).yields(ssh)
      @action.chown_provisioning_folder
    end
  end

  context "generating and uploading json" do
    def assert_json
      @env.ssh.expects(:upload!).with do |json, path|
        data = JSON.parse(json.read)
        yield data
        true
      end

      @action.setup_json
    end

    should "merge in the extra json specified in the config" do
      @env.config.chef.json = { :foo => "BAR" }
      assert_json do |data|
        assert_equal "BAR", data["foo"]
      end
    end

    should "add the directory as a special case to the JSON" do
      assert_json do |data|
        assert_equal @env.config.vm.project_directory, data["vagrant"]["directory"]
      end
    end

    should "add the config to the JSON" do
      assert_json do |data|
        assert_equal @env.config.vm.project_directory, data["vagrant"]["config"]["vm"]["project_directory"]
      end
    end

    should "upload a StringIO to dna.json" do
      StringIO.expects(:new).with(anything).returns("bar")
      File.expects(:join).with(@env.config.chef.provisioning_path, "dna.json").once.returns("baz")
      @env.ssh.expects(:upload!).with("bar", "baz").once
      @action.setup_json
    end
  end
end
