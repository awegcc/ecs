carlos:/workspace/storage # git status
On branch bugfix-release-ecs-3.0HF1-GISS
Your branch and 'origin/bugfix-release-ecs-3.0HF1-GISS' have diverged,
and have 1 and 7 different commits each, respectively.
  (use "git pull" to merge the remote branch into yours)
nothing to commit, working directory clean

carlos:/workspace/storage # git pull
Auto-merging datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/ChunkServer.java
CONFLICT (content): Merge conflict in datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/ChunkServer.java
Automatic merge failed; fix conflicts and then commit the result.

carlos:/workspace/storage # git status
On branch bugfix-release-ecs-3.0HF1-GISS
Your branch and 'origin/bugfix-release-ecs-3.0HF1-GISS' have diverged,
and have 1 and 7 different commits each, respectively.
  (use "git pull" to merge the remote branch into yours)

You have unmerged paths.
  (fix conflicts and run "git commit")

Changes to be committed:

        modified:   datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/scanner/bplustree/StateContext.java

Unmerged paths:
  (use "git add <file>..." to mark resolution)

        both modified:      datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/ChunkServer.java

carlos:/workspace/storage # git reset HEAD^
Unstaged changes after reset:
M       datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/ChunkServer.java
M       datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/scanner/bplustree/StateContext.java

carlos:/workspace/storage # git checkout .
carlos:/workspace/storage # git clean -xdf
carlos:/workspace/storage # git status
On branch bugfix-release-ecs-3.0HF1-GISS
Your branch is behind 'origin/bugfix-release-ecs-3.0HF1-GISS' by 7 commits, and can be fast-forwarded.
  (use "git pull" to update your local branch)

nothing to commit, working directory clean

carlos:/workspace/storage # git pull
Updating 20cf8ac..85534ea
Fast-forward
 datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/ChunkServer.java                         |  8 +++++
 datasvc/cm/src/main/java/com/emc/storageos/data/chunkmanager/scanner/bplustree/StateContext.java      |  6 ++++

 2 files changed, 13 insertions(+), 4 deletions(-)

carlos:/workspace/storage # git status
On branch bugfix-release-ecs-3.0HF1-GISS
Your branch is up-to-date with 'origin/bugfix-release-ecs-3.0HF1-GISS'.

nothing to commit, working directory clean




carlos:/workspace/storage # git status
On branch master
Your branch is up-to-date with 'origin/master'.

nothing to commit, working directory clean

carlos:/workspace/storage # git checkout release-ecs-3.1
Switched to branch 'release-ecs-3.1'
Your branch is ahead of 'origin/release-ecs-3.1' by 4 commits.
  (use "git push" to publish your local commits)
carlos:/workspace/storage # git status
On branch release-ecs-3.1
Your branch is ahead of 'origin/release-ecs-3.1' by 4 commits.
  (use "git push" to publish your local commits)

nothing to commit, working directory clean

carlos:/workspace/storage # git reset --hard origin/release-ecs-3.1
HEAD is now at df479c1 logs
carlos:/workspace/storage # git status
On branch release-ecs-3.1
Your branch is up-to-date with 'origin/release-ecs-3.1'.

nothing to commit, working directory clean



# delete remote branch
git push origin --delete bugfix-release-ecs-3.2-XING


