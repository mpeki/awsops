// Simply pipeline to run semantic-release on every commit.
// sem-rel configuration is in .releaserc.yml

pipeline {
  agent { label 'docker' }

  options {
    buildDiscarder(logRotator(numToKeepStr: '20'))
    // disableConcurrentBuilds()
    timestamps()
    timeout(time: 1, unit: 'HOURS')
  }

  environment {
    DOCKER_REGISTRY_USER='JenkinsADuser'
    DOCKER_REGISTRY_URL="https://repo.tiatechnology.com"
    GL_TOKEN = credentials('jenkins-api-git.tiatechnology.com')
    GL_URL='https://git.tiatechnology.com'
    ARC_TOOLBOX_VERSION="1.2.0"
  }

  stages {
    stage('Semantic-release'){
      steps {
        script {
          withDockerRegistry(credentialsId: "${DOCKER_REGISTRY_USER}", url: "${DOCKER_REGISTRY_URL}") {
            withDockerContainer("repo.tiatechnology.com/docker/arc-dev-container-toolbox:${ARC_TOOLBOX_VERSION}") {
              sh 'npx semantic-release'
            }
          }
        } // script
      }
    }
  }

  post {
    changed {
      script {
        // Send an email only if the build status has changed
        emailext subject: '$DEFAULT_SUBJECT',
          body: '$DEFAULT_CONTENT',
          recipientProviders: [
            [$class: 'CulpritsRecipientProvider'],
            [$class: 'DevelopersRecipientProvider'],
            [$class: 'RequesterRecipientProvider']
          ],
          replyTo: '$DEFAULT_REPLYTO'
      }
    }
  }

}
