-- Query templates for the application service; ? denotes a bound parameter.
-- Prepared-statement example: top ten accepted results for one level.
-- Bind ? to the selected level_id; account_id is omitted from public output.
SELECT a.username AS player_display_name,
       r.score, r.total_time_seconds, r.crash_count, r.completed_at
FROM flight_result AS r
JOIN player_account AS a ON a.account_id = r.account_id
WHERE r.level_id = ?
ORDER BY r.score DESC, r.total_time_seconds ASC,
         r.completed_at ASC, r.result_id ASC
LIMIT 10;

-- Private history: the service binds the authenticated account, not a
-- client-supplied account identifier. Bind both ? parameters server-side.
SELECT result_id, level_id, source_local_player_id, completed_at,
       total_time_seconds, crash_count, score, rating
FROM flight_result
WHERE account_id = ?
ORDER BY completed_at DESC, result_id ASC
LIMIT ?;
