#!/usr/bin/env just --justfile

REPO_NAME := "nekojump"
VERSIOn := "3"

alias dist := package

package:
    tar cavf {{REPO_NAME}}-v{{VERSIOn}}.tar.gz nekojump.plugin.zsh LICENSE 

clean:
    git clean -ffdx

setup-remotes:
    git remote add github git@github.com:0x61nas/{{REPO_NAME}}.git
    git remote add gitlab git@gitlab.com:anelgarhy/{{REPO_NAME}}.git
    git remote add codeberg ssh://git@codeberg.org/0x61nas/{{REPO_NAME}}.git
    git remote add disroot ssh://git@git.disroot.org/anas/{{REPO_NAME}}.git
    git remote add tangled git@tangled.org:anas.tngl.sh/{{REPO_NAME}}
    git remote add codefloe ssh://git@codefloe.com/anas/{{REPO_NAME}}.git

# Push the code to all remotes
push FLAGS="-u" BRANSH="aurora":
    git push {{FLAGS}} github {{BRANSH}}
    git push {{FLAGS}} gitlab {{BRANSH}}
    git push {{FLAGS}} codeberg {{BRANSH}}
    git push {{FLAGS}} disroot {{BRANSH}}
    git push {{FLAGS}} tangled {{BRANSH}}
    git push {{FLAGS}} codefloe {{BRANSH}}

# Push the git tags to all remotes
pusht: push
    git push --tags github
    git push --tags gitlab
    git push --tags codeberg
    git push --tags disroot
    git push --tags tangled
    git push --tags codefloe

try:
    PS1='%d%% ' zsh --no-rcs
