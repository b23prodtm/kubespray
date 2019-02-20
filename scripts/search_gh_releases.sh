#!/usr/bin/env bash
function install() {
	git clone git@github.com:HugoGiraudel/github-release-search
	cd github-release-search
	npm install
	cd ..
}

[ "$#" -lt 2 ] && echo "Usage $0 : OAUTH_TOKEN \"hello\" --repo owner/repo --since 04/23/2017 --format MM/DD/YYYY"
[ ! -f github-release-search/package.json ] && install
export OAUTH_TOKEN=$1
shift
cd github-release-search
npm run fetch -- $*
npm run search -- $*


