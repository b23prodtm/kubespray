#!/usr/bin/env bash
function install() {
	git clone git@github.com:HugoGiraudel/github-release-search
	cd github-release-search
	npm install
	cd ..
}

[ "$#" -lt 1 ] && echo "Usage $0 : \"hello\" --repo owner/repo" && exit 0;
[ "$#" -lt 2 ] && [ ! -f .env ] && echo "Usage $0 : OAUTH_TOKEN \"hello\" --repo owner/repo [--since 04/23/2017 --format MM/DD/YYYY]" && exit 0;
[ ! -f github-release-search/package.json ] && install
if [ -f .env ]; then
	source .env
else
	export OAUTH_TOKEN=$1
	shift
fi
cd github-release-search
npm run fetch -- $*
npm run search -- $*
