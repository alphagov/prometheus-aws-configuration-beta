control "operating_system" do

  describe os.family do
    it { should eq 'debian' }
  end

  describe file('/etc/cron.d/config_pull') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  describe file('/root/format_disk.sh') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  describe file('/root/watch_prometheus_dir') do
    its('owner') { should eq 'root' }
    its('group') { should eq 'root' }
    its('mode')  { should cmp '0755'}
  end

  describe service('prometheus') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe service('prometheus-node-exporter') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe package('prometheus') do
    it { should be_installed }
  end

  describe package('prometheus-node-exporter') do
    it { should be_installed }
  end

  describe mount('/mnt') do
    it { should be_mounted }
    its('device') { should eq  '/dev/xvdh' }
    its('type') { should eq  'ext4' }
  end

  describe directory('/etc/prometheus/targets') do
    it { should exist }
  end
end
