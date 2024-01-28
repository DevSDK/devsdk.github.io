#sh 
#blish.sh

git checkout gh-pages
rm -rf _site/
JEKYLL_ENV=production bundle exec jekyll build
git add .
git commit --amend -m "`date` $1"
git push -f origin gh-pages

git subtree split --prefix _site/ -b master
git push -f origin master
git branch -D master
