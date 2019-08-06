#sh 
#blish.sh

git checkout gh-pages
rm -rf _site/
JEKYLL_ENV=production jekyll build
git add .
git commit --amend -m "`date` $1"
git push -f stable gh-pages

git subtree split --prefix _site/ -b master
git push -f stable master
git branch -D master
