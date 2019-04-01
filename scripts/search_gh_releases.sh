#!/usr/bin/env bash
function install() {
	git clone git@github.com:HugoGiraudel/github-release-search
	cd github-release-search
	npm install
	cd ..
}
function register_OAUTH_TOKEN() {
	echo "export OAUTH_TOKEN=$1" >> ~/.env
	logger -s -t $0 "Registered new environment OAUTH_TOKEN in shell .bash_profile"
}
[ "$#" -lt 1 ] && echo "Usage $0 : \"hello\" --repo owner/repo" && exit 0;
[ "$#" -lt 2 ] && [ ! -f ~/.env ] && echo "Usage $0 : [OAUTH_TOKEN] \"hello\" --repo owner/repo [--since 04/23/2017 --format MM/DD/YYYY]" && exit 0;
[ ! -f github-release-search/package.json ] && install
if [ -z $OAUTH_TOKEN ]; then
	register_OAUTH_TOKEN $1
	shift
fi
source ~/.env
cd github-release-search
echo -e " Github Releases search Script
~~~
https://github.com/HugoGiraudel/github-release-search
"
npm run fetch -- $*
npm run search -- $*
