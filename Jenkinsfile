pipeline {
    agent any
    
    parameters {
        choice(
            name: 'TERRAFORM_ACTION',
            choices: ['apply', 'destroy'],
            description: 'Choose whether to deploy (apply) or destroy infrastructure'
        )
        booleanParam(
            name: 'SKIP_SAST',
            defaultValue: false,
            description: 'Skip Static Code Analysis stage (useful for destroy operations)'
        )
        booleanParam(
            name: 'SKIP_SNYK',
            defaultValue: false,
            description: 'Skip Snyk Security Scan (useful for destroy operations)'
        )
    }
    
    environment {
        AWS_REGION        = 'us-west-1'
        SONARQUBE_URL     = "https://sonarcloud.io"
        SONAR_SCANNER_HOME = "/opt/sonar-scanner"
        JIRA_SITE         = "https://jastekops.atlassian.net/"
        JIRA_PROJECT      = "SCRUM"
    }

    stages {
        stage('Set AWS Credentials') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                      echo "Caller identity:"
                      aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/jastek69/Armageddon-C7-LAB4-SEIR.git'
            }
        }

        stage('Static Code Analysis (SAST)') {
            when {
                expression { params.SKIP_SAST == false }
            }
            steps {
                withCredentials([string(credentialsId: 'SONARQUBE_TOKEN', variable: 'SONAR_TOKEN')]) {
                    sh """
                      ${SONAR_SCANNER_HOME}/bin/sonar-scanner \
                        -Dsonar.projectKey=jastekops_pipeline-test-sonarqube \
                        -Dsonar.organization=jastekops \
                        -Dsonar.host.url=${SONARQUBE_URL} \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                }
            }
        }

        stage('Snyk Security Scan') {
            when {
                expression { params.SKIP_SNYK == false }
            }
            steps {
                withCredentials([string(credentialsId: 'SNYK_AUTH_TOKEN', variable: 'SNYK_TOKEN')]) {
                    sh """
                      snyk auth ${SNYK_TOKEN}
                      snyk monitor || echo 'No supported files found, monitoring skipped.'
                    """
                }
            }
        }

        stage('Scaffolding Validation') {
            steps {
                sh '''
                    set -euo pipefail
                    test -f terraform_startup.sh
                    test -f terraform_apply.sh
                    test -d Tokyo
                    test -d global
                    test -d newyork_gcp
                    test -d saopaulo
                '''
            }
        }

        stage('Terraform Deploy') {
            steps {
                withCredentials([
                                                                        [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds'],
                  file(credentialsId: 'secrets-env', variable: 'SECRETS_FILE'),
                  file(credentialsId: 'gcp-credentials-json', variable: 'GCP_CREDS'),
                  file(credentialsId: 'gcp-nihonmachi-cert', variable: 'GCP_CERT'),
                  file(credentialsId: 'gcp-nihonmachi-key', variable: 'GCP_KEY')
                ]) {
                  script {
                    if (params.TERRAFORM_ACTION == 'destroy') {
                      echo "=== DESTROYING INFRASTRUCTURE ==="
                                            sh '''
                                                set -euo pipefail
                        chmod +x terraform_destroy.sh
                        source "$SECRETS_FILE"
                        
                        # Set up GCP credential paths
                        export GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDS"
                        export TF_VAR_gcp_credentials="$GCP_CREDS"
                        
                        # Create symlinks for certificates
                        mkdir -p newyork_gcp/certs
                        ln -sf "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt || cp "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt
                        ln -sf "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key || cp "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key
                        
                        AWS_REGION=${AWS_REGION} \
                        AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                        ./terraform_destroy.sh
                                            '''
                    } else {
                                            echo "=== DEPLOYING INFRASTRUCTURE (STAGED SCAFFOLD) ==="
                                            sh '''
                                                set -euo pipefail
                                                chmod +x terraform_startup.sh
                        source "$SECRETS_FILE"
                        
                        # Set up GCP credential paths
                        export GOOGLE_APPLICATION_CREDENTIALS="$GCP_CREDS"
                        export TF_VAR_gcp_credentials="$GCP_CREDS"
                        
                        # Create symlinks for certificates
                        mkdir -p newyork_gcp/certs
                        ln -sf "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt || cp "$GCP_CERT" newyork_gcp/certs/nihonmachi-ilb.crt
                        ln -sf "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key || cp "$GCP_KEY" newyork_gcp/certs/nihonmachi-ilb.key
                        
                        AWS_REGION=${AWS_REGION} \
                        AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                        AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                                                ./terraform_startup.sh
                                            '''
                    }
                  }
                }
            }
        }

        stage('Deploy to S3') {
            when {
                expression { params.TERRAFORM_ACTION == 'apply' }
            }
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        set -euo pipefail
                        python3 -m ensurepip --upgrade 2>/dev/null || true
                        python3 -m pip install --user --quiet boto3

                        source_dir=""
                        for candidate in ./S3-DELIVERABLES ./deliverables/S3-DELIVERABLES ./LAB4/S3-DELIVERABLES; do
                            if [ -d "$candidate" ]; then
                                source_dir="$candidate"
                                break
                            fi
                        done
                        if [ -z "$source_dir" ]; then
                            source_dir=$(find . -maxdepth 5 -type d -name 'S3-DELIVERABLES' | head -n 1 || true)
                        fi
                        if [ -z "$source_dir" ]; then
                            echo "WARN: No S3-DELIVERABLES directory found. Skipping Deploy to S3 stage."
                            exit 0
                        fi

                        script_path=""
                        for candidate in ./deploy-to-s3.py ./scripts/deploy-to-s3.py; do
                            if [ -f "$candidate" ]; then
                                script_path="$candidate"
                                break
                            fi
                        done
                        if [ -z "$script_path" ]; then
                            script_path=$(find . -maxdepth 5 -type f -name 'deploy-to-s3.py' | head -n 1 || true)
                        fi

                        if [ -n "$script_path" ]; then
                            python3 "$script_path" --source-dir "$source_dir" --delete
                        else
                            echo "WARN: deploy-to-s3.py not found, using aws s3 sync fallback"
                            bucket_name=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'jenkins-bucket-')].Name | [0]" --output text)
                            if [ -z "$bucket_name" ] || [ "$bucket_name" = "None" ]; then
                                echo "ERROR: Could not find target bucket with prefix 'jenkins-bucket-'"
                                exit 1
                            fi
                            aws s3 sync "$source_dir" "s3://$bucket_name/" --delete
                        fi
                    '''
                }
            }
        }
    }

    post {
        success { 
            script {
                if (params.TERRAFORM_ACTION == 'destroy') {
                    echo 'Infrastructure destruction completed successfully!'
                } else {
                    echo 'Terraform deployment completed successfully!'
                }
            }
        }
        failure { 
            script {
                if (params.TERRAFORM_ACTION == 'destroy') {
                    echo 'Infrastructure destruction failed!'
                } else {
                    echo 'Terraform deployment failed!'
                }
            }
        }
    }
}

def createJiraTicket(String issueTitle, String issueDescription) {
    script {
        jiraNewIssue site: "${JIRA_SITE}",
                     projectKey: "${JIRA_PROJECT}",
                     issueType: "Bug",
                     summary: issueTitle,
                     description: issueDescription,
                     priority: "High"
    }
}
