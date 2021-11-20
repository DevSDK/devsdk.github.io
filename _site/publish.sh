#sh 
#blish.sh

git checkout gh-pages
rm -rf _site/
JEKYLL_ENV=production bundle exec jekyll build
git add .
git commit -m "`date` $1"
git push origin gh-pages

git subtree split --prefix _site/ -b master
git push -f origin master
git branch -D master
