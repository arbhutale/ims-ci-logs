pipeline {
    agent any

    parameters {
        string(name: 'BRANCH', defaultValue: 'dev', description: 'Git branch to build')
    }

    environment {
        NAMESPACE = 'dev'
        IMAGE_NAME = 'ims-trace-ui'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: "${params.BRANCH}", url: 'https://github.com/arbhutale/ims-ci-logs.git'
            }
        }

        stage('Build Image') {
            steps {
                sh """
                    docker build -t ${IMAGE_NAME}:latest .
                """
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                    docker save ${IMAGE_NAME}:latest | /host/bin/k3s ctr -n k8s.io images import - || docker save ${IMAGE_NAME}:latest | ctr -n k8s.io images import -
                    kubectl rollout restart deployment/web-log-viewer -n ${NAMESPACE}
                    kubectl rollout status deployment/web-log-viewer -n ${NAMESPACE} --timeout=120s
                """
            }
        }

        stage('Health Check') {
            steps {
                sh """
                    curl -s -k -o /dev/null -w "%{http_code}\n" https://logs.smartseth.com/ || true
                """
            }
        }
    }

    post {
        success {
            echo "CI Logs & Tracer UI Pipeline Completed Successfully!"
        }
        failure {
            echo "CI Logs Pipeline Failed."
        }
    }
}
