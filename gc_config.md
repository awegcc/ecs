
https://asdwiki.isus.emc.com:8443/display/ECS/REPO+GC+Configurations

cf_client='/opt/emc/xdoctor/tools/ee_scripts/cf_client'
cf_client='/opt/storageos/tools/cf_client'
																								GC configurations                   defaults		tune
$cf_client --list --name com.emc.ecs.chunk.gc.repo.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.repo.verification.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.repo.verification.new_run_interval --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.repo.partial.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.deletejobscanner.timeout --user emcmonitor --password ChangeMe                        # 30 min
$cf_client --list --name com.emc.ecs.chunk.gc.deletejobscanner.job_pause_interval --user emcmonitor --password ChangeMe             # 20 ms
$cf_client --list --name com.emc.ecs.chunk.gc.deletejobscanner.query_conflict_range_interval --user emcmonitor --password ChangeMe  # 
$cf_client --list --name com.emc.ecs.chunk.gc.repo.reclaimer.no_recycle_window --user emcmonitor --password ChangeMe                # 78 hours
$cf_client --list --name com.emc.ecs.chunk.gc.repo.repoReclaimer_batch_pause_interval --user emcmonitor --password ChangeMe         # 100 ms
$cf_client --list --name com.emc.ecs.chunk.gc.scanner.task.force_start_time --user emcmonitor --password ChangeMe                   # 30 min
$cf_client --list --name com.emc.ecs.chunk.gc.repo.verification.new_run_interval --user emcmonitor --password ChangeMe              # 6  hours
$cf_client --list --name com.emc.ecs.chunk.gc.repo.verification.rr_scanner_timeout --user emcmonitor --password ChangeMe            # 120 min
$cf_client --list --name com.emc.ecs.chunk.gc.repo.verification.run_interval --user emcmonitor --password ChangeMe                  # 15  min

$cf_client --list --name com.emc.ecs.chunk.geo.chunk_replication_auto_fix_enabled --user emcmonitor --password ChangeMe


$cf_client --list --name com.emc.ecs.chunk.gc.btree.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.scanner.verification.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.reclaimer.level2.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.scanner.level2.verification.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.scanner.throttling --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.scanner.new_run_interval --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.btree.occupancy.min_major_interval --user emcmonitor --password ChangeMe              # 100
$cf_client --list --name com.emc.ecs.chunk.gc.btree.occupancy.skip_error_chunks_timestamp --user emcmonitor --password ChangeMe


$cf_client --list --name com.emc.ecs.prtable.gc.enabled --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.prtable.gc.record_expiration --user emcmonitor --password ChangeMe
$cf_client --list --name com.emc.ecs.chunk.gc.repo.partial.task.generator.max_pending_task_num --user emcmonitor --password ChangeMe # 75			# 100



com.emc.ecs.chunk.gc.btree.reclaimer.new_round_interval -> 2 hours
com.emc.ecs.chunk.gc.btree.scanner.throttling -> 90
com.emc.ecs.chunk.gc.btree.scanner.new_run_interval -> 2 hours
com.emc.ecs.chunk.gc.scanner.task.cache_expire -> 1.5 hours
com.emc.ecs.chunk.gc.scanner.task.max.btree to 10000



We can tune these parameters like this to speed up cleanup jobs processing.

com.emc.ecs.chunk.gc.deletejobscanner.job_pause_interval -> 5 ms
com.emc.ecs.chunk.gc.deletejobscanner.query_conflict_range_interval -> 30 ms
com.emc.ecs.chunk.gc.deletejobscanner.timeout -> 60 min


