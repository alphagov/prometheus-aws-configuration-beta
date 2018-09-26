export SSH_KEY="~/.ssh/id_rsa"
export SSH_USER="ubuntu"
# sets the test user to your git user name
# export TF_VAR_test_user=$(git config user.name | sed -E 's/[ ]+/-/g' | awk '{print tolower($0)}')
export TF_VAR_test_user=ken-testing
