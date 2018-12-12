# generic tests we would expect of every node

control "operating_system" do
  describe os.family do
    it { should eq 'debian' }
  end

  describe service('prometheus-node-exporter') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe package('prometheus-node-exporter') do
    it { should be_installed }
  end

  describe port(9100) do
    it { should be_listening }
    its('processes') {should include 'prometheus-node'}
  end
end
