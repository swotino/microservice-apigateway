def COLORS = [ 'SUCCESS': '#00AA00', 'FAILURE': '#AA0000', 'ABORTED': '#000000']
pipeline {
    agent any

    environment {
        NEXUS_HOST='10.166.0.17'
        NEXUS_PORT=8081
        NEXUS_USER='admin'
        NEXUS_PASSWORD='admin'
        NEXUS_REPOSITORY='apigateway.release'
        NEXUS_REPOSITORIES='maven.dependencies'
        NEXUS_GROUP='com.microservice'

        SETTINGS='settings.xml'
    }

    stages {
        stage('Get from GIT') {
            steps {
                echo 'Fetching data...'
                git branch: 'master', url: 'https://github.com/swotino/microservice-apigateway.git'
            }
        }

        stage('Maven Install') {
            steps {
                echo 'Maven Install'
                sh 'mvn -s $SETTINGS clean install -DskipTests'
            }
        }

        stage('Maven CheckStyle') {
            steps {
                echo 'Maven Checkstyle'
                sh 'mvn -s $SETTINGS checkstyle:checkstyle'
            }
        }

        stage('Sonarqube') {
            environment {
                SCANNER = tool 'sonar-scanner'
            }

            steps {
                echo 'SonarQube Scanner'
                withSonarQubeEnv('sonarqube-server') {
                    sh """$SCANNER/bin/sonar-scanner \
                    -Dsonar.projectKey=apigateway \
                    -Dsonar.projectName=API-Gateway \
                    -Dsonar.projectVersion=1.0 \
                    -Dsonar.sources=src/ \
                    -Dsonar.java.binaries=target/test-classes/com/microservices/apigateway/apigateway \
                    -Dsonar.java.checkstyle.reportPaths=target/checkstyle-result.xml \
                    """
                }
            }
        }

        stage('Populate versions') {
            steps {
                sh 'mkdir -p versions'
                sh "cp target/**.jar versions/apigateway-v${BUILD_NUMBER}.jar"
            }
        }

        stage('Jenkins Artifact') {
            steps {
                echo 'Creating jenkins artifact...'
                archiveArtifacts artifacts: 'versions/*.jar'
            }
        }

        stage ('Nexus') {
            steps {
                echo 'Nexus uploading...'
                nexusArtifactUploader artifacts: [
                    [artifactId: 'api-gateway', classifier: '', file: 'versions/apigateway-v$BUILD_NUMBER.jar', type: 'jar']
                    ],
                    credentialsId: 'nexus-auth',
                    groupId: NEXUS_GROUP,
                    nexusUrl: "${NEXUS_HOST}:${NEXUS_PORT}",
                    nexusVersion: 'nexus3',
                    protocol: 'http',
                    repository: NEXUS_REPOSITORY,
                    version: BUILD_NUMBER
            }
        }
    }

    post {
        always {
            echo 'Slack notify'
            slackSend channel: '#microservizi',
                color: COLORS[currentBuild.currentResult],
                message: "${currentBuild.currentResult}: Job ${JOB_NAME} build ${BUILD_NUMBER}.\nInfo at ${BUILD_URL}"
        }
    }
}