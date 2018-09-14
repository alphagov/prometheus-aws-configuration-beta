environment = attribute "environment", {}
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
ENV['AWS_REGION'] = 'eu-west-1'


control "aws_cloud_resources" do
  describe aws_ec2_instance(prometheus_instance_id) do
    its('tags') { should include(key: 'ManagedBy', value: 'terraform')}
    its('image_id') { should eq 'ami-0ee06eb8d6eebcde0' }
    its('root_device_type') { should eq 'ebs'}
    its('root_device_name') { should eq '/dev/sda1'}
    its('architecture') { should eq 'x86_64'}
    its('virtualization_type') { should eq 'hvm'}
    its('key_name') { should eq "#{environment}-prom-key"}
  end

  describe aws_iam_role("prometheus_profile_#{environment}") do
    it { should exist }
  end

  describe aws_iam_policy("prometheus_instance_profile_#{environment}") do
    it { should exist }
    its('attached_roles') { should include "prometheus_profile_#{environment}" }
    it { should be_attached }
    it { should have_statement(Action: ['s3:Get*','s3:ListBucket'], Effect: 'Allow', Sid: 's3Bucket') }
    it { should have_statement(Action: 'ec2:Describe*', Effect: 'Allow', Resource: '*', Sid: 'ec2Policy') }
    it { should have_statement(Resource: "arn:aws:s3:::#{environment}/*") }
    it { should have_statement(Resource: "arn:aws:s3:::#{environment}") }    
    it { should have_statement(Resource: 'arn:aws:s3:::gds-prometheus-targets-dev') }
    it { should have_statement(Resource: 'arn:aws:s3:::gds-prometheus-targets-dev/*') }
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

  ##Subnetwork related things
  
  subnet_ids.each do |subnet_id|
    describe aws_subnet(subnet_id: subnet_id) do
      it { should exist }
      its('available_ip_address_count') { should eq 9 }
    end
  end
end
