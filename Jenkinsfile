def COLOR_MAP = [
    'SUCCESS': '#00FF00',
    'UNSTABLE': '#FFFF00',
    'FAILURE': '#FF0000',
    'ABORTED': '#000000'
]

pipeline {

    agent any

    environment {
        // Path to the settings.xml file
        MAVEN_SETTINGS = 'settings.xml'

        // Nexus configuration
        NEXUS_HOST = '192.168.10.102'
        NEXUS_PORT = 8081
        NEXUS_USER = 'admin'
        NEXUS_PASSWORD = 'admin123'
        NEXUS_REPOSITORIES = 'microservices.repositories'
        NEXUS_GROUP = 'microservices.demo'
        NEXUS_RELEASE = 'microservices.api-gateway'
    }

    stages {
        stage('Fetch data from GitHub') {
            steps {
                echo 'Fetching data from GitHub..'
                git branch: 'master', credentialsId: 'GitHub Jenkins', url: 'https://github.com/swotino/microservice-apigateway.git'
            }
        }

        stage('Maven install') {
            steps {
                echo 'Maven installing..'
                sh 'mvn -s $MAVEN_SETTINGS clean install -DskipTests'
            }
        }

        stage('Maven checkstyle') {
            steps {
                echo 'Checkstyle..'
                sh 'mvn -s $MAVEN_SETTINGS checkstyle:checkstyle'
            }
        }

        stage('SonarQube Scanner') {
            environment {
                scanner = tool 'SonarQubeScanner'
            }
            steps {
                echo 'SonarQube Scanner..'
                withSonarQubeEnv('SonarQube Server') {
                    sh """$scanner/bin/sonar-scanner \
                    -Dsonar.projectKey=api-gateway \
                    -Dsonar.projectName=API-Gateway \
                    -Dsonar.projectVersion=${BUILD_NUMBER} \
                    -Dsonar.sources=src/ \
                    -Dsonar.java.binaries=target/test-classes/com/microservices/apigateway/apigateway/ \
                    -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml \
                    """
                }

                echo 'Waiting for SonarQube analysis to complete..'
                timeout(time: 60, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Copy Artifacts') {
            steps {
                echo 'Artifacts..'
                sh 'mkdir -p versions'
                sh 'cp target/*.jar versions/api-gateway-${BUILD_NUMBER}.jar'
            }
        }

        stage('Create an artifact') {
            steps {
                echo 'Creating artifact..'
                archiveArtifacts artifacts: 'versions/*.jar'
            }
        }

        stage('Uploading to Nexus') {
            steps {
                echo 'Uploading to Nexus..'
                nexusArtifactUploader (
                    artifacts: [[
                        artifactId: 'api-gateway',
                        classifier: '',
                        file: 'versions/api-gateway-$BUILD_NUMBER.jar',
                        type: 'jar']],
                    credentialsId: 'nexuslogin',
                    groupId: NEXUS_GROUP,
                    nexusUrl: '192.168.10.102:8081',
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    repository: NEXUS_RELEASE,
                    version: BUILD_NUMBER
                )
            }
        }
    }

    post {
        always {
            echo 'Slack notifications..'
            slackSend color: COLOR_MAP[currentBuild.currentResult],
                message: "${currentBuild.currentResult}: Job ${JOB_NAME} build ${BUILD_NUMBER}.\n More info at ${BUILD_URL}",
                channel: '#springrest'
        }
    }
}