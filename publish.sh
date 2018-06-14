#sh 
#blish.sh

git checkout site
rm -rf _site/
jekyll build
git add .
git commit -m "`date` $1"
git push test site:master

git subtree split --prefix _site/ -b gh-pages 
git push -f test  gh-pages:gh-pages 
git branch -D gh-pages
