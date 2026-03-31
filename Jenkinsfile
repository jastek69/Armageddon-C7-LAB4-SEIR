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

        stage('Initialize Terraform') {
            steps {
                sh 'terraform init'
            }
        }

        /*
         * This stage is specifically for deploying the Tokyo environment, which requires assuming multiple roles.
         * It uses a helper script to assume the necessary roles before running Terraform commands.
         * TO:DO: Refactor this to be more dynamic and reusable for other environments if needed.
         
        stage('Terraform Deploy - Tokyo') {
            steps {
                sh """
                    # Get role ARNs from jenkins infrastructure
                    COMPUTE_ROLE="arn:aws:iam::015195098145:role/jenkins-assume-compute-role"
                    SECURITY_ROLE="arn:aws:iam::015195098145:role/jenkins-assume-security-role"
                    APP_ROLE="arn:aws:iam::015195098145:role/jenkins-assume-application-role"
      
                # Assume all three roles (Tokyo needs all services)
                source assume-role-helper.sh "\$COMPUTE_ROLE" "jenkins-compute-deployment" "tokyo-deploy"
      
                cd Tokyo/
                terraform init -upgrade
                terraform plan
                terraform apply -auto-approve
                """
            }
        }
    */
    
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
                      sh """
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
                      """
                    } else {
                      echo "=== DEPLOYING INFRASTRUCTURE ==="
                      sh """
                        chmod +x terraform_apply.sh
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
                        ./terraform_apply.sh
                      """
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
                        pip3 install --user boto3
                        python3 deploy-to-s3.py --source-dir ./S3-DELIVERABLES --delete
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
