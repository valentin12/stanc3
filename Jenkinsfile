@Library('StanUtils')
import org.stan.Utils

def utils = new org.stan.Utils()

/* Functions that runs a sh command and returns the stdout */
def runShell(String command){
    def output = sh (returnStdout: true, script: "${command}").trim()
    return "${output}"
}

def tagName() {
    if (env.TAG_NAME) {
        env.TAG_NAME
    } else if (env.BRANCH_NAME == 'master') {
        'nightly'
    } else {
        'unknown-tag'
    }
}
pipeline {
    agent { label 'linux' }
    parameters {
        string(defaultValue: 'master', name: 'git_branch',
               description: "Please specify a git branch ( develop ), git hash ( aace72b6ccecbb750431c46f418879b325416c7d ), pull request ( PR-123 ), pull request from fork ( PR-123 )")
    }
    environment {
        GITHUB_TOKEN = credentials('6e7c1e8f-ca2c-4b11-a70e-d934d3f6b681')
    }
    options {parallelsAlwaysFailFast()}
    stages {
        stage("Build and test static release binaries") {
            failFast true
            parallel {
                stage("Build & test Mac OS X binary") {
                    agent { label "osx && ocaml" }
                    steps {
                        deleteDir()
                        retry(3) { checkout scm }

                        runShell("""
                            eval \$(opam env)
                            opam update || true
                            bash -x scripts/install_build_deps.sh
                            dune subst
                            dune build @install
                        """)

                        echo runShell("""
                            eval \$(opam env)
                            time dune runtest --verbose
                        """)

                        sh "mkdir -p bin && mv `find _build -name stanc.exe` bin/mac-stanc"
                        sh "mv _build/default/src/stan2tfp/stan2tfp.exe bin/mac-stan2tfp"

                        stash name:'mac-exe', includes:'bin/*'
                        archiveArtifacts 'bin/*'
                    }
                    post { always { runShell("rm -rf ./*") }}
                }
                stage("Build stanc.js") {
                    agent {
                        dockerfile {
                            filename 'docker/debian/Dockerfile'
                            //Forces image to ignore entrypoint
                            args "-u root --entrypoint=\'\'"
                        }
                    }
                    steps {
                        deleteDir()
                        retry(3) { checkout scm }

                        runShell("""
                            eval \$(opam env)
                            dune subst
                            dune build --profile release src/stancjs
                        """)

                        sh "mkdir -p bin && mv `find _build -name stancjs.bc.js` bin/stanc.js"
                        sh "mv `find _build -name index.html` bin/load_stanc.html"
                        stash name:'js-exe', includes:'bin/*'
                        archiveArtifacts 'bin/*'
                    }
                    post {always { runShell("rm -rf ./*")}}
                }
                stage("Build & test a static Linux binary") {
                    agent {
                        dockerfile {
                            filename 'docker/static/Dockerfile'
                            //Forces image to ignore entrypoint
                            args "-u 1000 --entrypoint=\'\'"
                        }
                    }
                    steps {
                        deleteDir()
                        retry(3) { checkout scm }

                        runShell("""
                            eval \$(opam env)
                            dune subst
                            dune build @install --profile static
                        """)

                        echo runShell("""
                            eval \$(opam env)
                            time dune runtest --profile static --verbose
                        """)

                        sh "mkdir -p bin && mv `find _build -name stanc.exe` bin/linux-stanc"
                        sh "mv `find _build -name stan2tfp.exe` bin/linux-stan2tfp"

                        stash name:'linux-exe', includes:'bin/*'
                        archiveArtifacts 'bin/*'
                    }
                    post {always { runShell("rm -rf ./*")}}
                }
                stage("Build & test static Windows binary") {
                    agent { label "WSL" }
                    steps {
                        deleteDir()
                        retry(3) { checkout scm }
                        
                        bat "bash -cl \"cd test/integration\""
                        bat "bash -cl \"find . -type f -name \"*.expected\" -print0 | xargs -0 dos2unix\""
                        bat "bash -cl \"cd ..\""
                        bat "bash -cl \"eval \$(opam env) make clean; dune subst; dune build -x windows; dune runtest --verbose\""
                        bat """bash -cl "rm -rf bin/*; mkdir -p bin; mv _build/default.windows/src/stanc/stanc.exe bin/windows-stanc" """
                        bat "bash -cl \"mv _build/default.windows/src/stan2tfp/stan2tfp.exe bin/windows-stan2tfp\""
                        stash name:'windows-exe', includes:'bin/*'
                    }
                }
            }
        }
    }
}
