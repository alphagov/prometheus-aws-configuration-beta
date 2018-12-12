control "prometheus" do

  # basic prometheus functionality
  describe package('prometheus') do
    it { should be_installed }
  end

  describe service('prometheus') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(9090) do
    it { should be_listening }
    its('processes') {should include 'prometheus'}
  end

  # prometheus backing storage
  describe mount('/mnt') do
    it { should be_mounted }
    its('device') { should eq  '/dev/xvdh' }
    its('type') { should eq  'ext4' }
  end

  describe file('/root/format_disk.sh') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  # prometheus configuration for scraping the paas
  describe file('/etc/cron.d/config_pull') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  describe file('/root/watch_prometheus_dir') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  describe directory('/etc/prometheus/targets') do
    it { should exist }
  end

  # http proxy for managing X-Cf-App-Instance headers
  describe port(8080) do
    it { should be_listening }
    its('processes') {should include 'nginx'}
  end

  # nginx fronting prometheus with auth
  describe port(80) do
    it { should be_listening }
    its('processes') {should include 'nginx'}
  end

  describe http('http://localhost/health') do
    its('status') {should cmp 200}
    its('body') {should cmp 'Static health check'}
  end

  describe http('http://localhost/') do
    its('status') {should cmp 401}
  end

  describe http('http://localhost/', auth: {user: 'grafana', pass: 'hello world'}) do
    its('status') {should_not cmp 401}
  end

  describe service('nginx') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end
end
