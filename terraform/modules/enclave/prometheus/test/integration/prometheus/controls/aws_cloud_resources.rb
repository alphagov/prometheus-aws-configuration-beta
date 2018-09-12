prometheus_instance_id = attribute "prometheus_id", {}
s3_bucket_id = attribute "prom_s3_config_bucket", {}
subnet_ids = attribute "subnet_ids", {}
routing_table = attribute "routing_table", {}
allow_ip_subnets = [
    "213.86.153.212/32",
    "213.86.153.213/32",
    "213.86.153.214/32",
    "213.86.153.235/32",
    "213.86.153.236/32",
    "213.86.153.237/32",
    "85.133.67.244/32",
]


control "aws_cloud_resources" do
  describe aws_ec2_instance(prometheus_instance_id) do
    its('tags') { should include(key: 'ManagedBy', value: 'terraform')}
    its('image_id') { should eq 'ami-e4ad5983' }
    its('root_device_type') { should eq 'ebs'}
    its('root_device_name') { should eq '/dev/sda1'}
    its('architecture') { should eq 'x86_64'}
    its('virtualization_type') { should eq 'hvm'}
    its('key_name') { should eq 'perf-test-prom-key'}
  end

  describe aws_iam_role('prometheus_profile') do
    it { should exist }
  end

  describe aws_iam_policy('prometheus_instance_profile') do
    it { should exist }
    its('attached_roles') { should include "prometheus_profile" }
    it { should be_attached }
    it { should have_statement(Action: ['s3:Get*','s3:ListBucket'], Effect: 'Allow', Sid: 's3Bucket') }
    it { should have_statement(Action: 'ec2:Describe*', Effect: 'Allow', Resource: '*', Sid: 'ec2Policy') }
    its('statement_count') { should cmp 2 }
  end

  describe aws_s3_bucket_object(bucket_name: s3_bucket_id, key: 'prometheus/prometheus.yml') do
    it { should exist }
    it { should_not be_public }
  end

  describe aws_s3_bucket(bucket_name: s3_bucket_id) do
    it { should exist }
    it { should_not be_public }
  end

  describe aws_security_group(group_name: 'observe-hub-perf-test-prometheus-instance') do
    it { should exist }
    its('group_name') { should eq 'observe-hub-perf-test-prometheus-instance' }
    it { should allow_out(port: '9100', ipv4_range: '10.0.0.0/22') }
    it { should allow_in(port: '22', ipv4_range: allow_ip_subnets) }
    it { should allow_out(port: '53', ipv4_range: '10.0.1.251/32') }
    it { should allow_out(port: '53', ipv4_range: '10.0.1.253/32') }
    it { should allow_out(port: '8080', ipv4_range: '10.0.1.87/32') }
  end

  describe aws_security_group(group_name: 'prometheus_to_ec2') do
    it { should exist }
    its('group_name') { should eq 'prometheus_to_ec2' }
    it { should allow_in_only(port: '443', ipv4_range: '10.0.3.32/27') }
  end

  ##Subnetwork related things
  #
  subnet_ids.each do |subnet_id|
    describe aws_subnet(subnet_id: subnet_id) do
      it { should exist }
      its('available_ip_address_count') { should eq 9 }
    end
  end

  describe aws_route_table(routing_table) do
    it { should exist }
  end

end