# Data dictionary - goals_master_final.csv

| Column | Type | Description |
|---|---|---|
| goal_id | chr | Unique goal identifier |
| Player | chr | Lionel Messi / C. Ronaldo |
| Date | date | Match date |
| Comp | chr | Competition (FBref) |
| Round | chr | Round/stage label (FBref) |
| Venue | chr | Home / Away / Neutral (goal log) |
| Venue_match | chr | Venue from match log (should equal Venue) |
| Squad | chr | Player's team (FBref) |
| Opponent | chr | Opponent (FBref, with country prefix) |
| Opp_clean | chr | Opponent without country prefix |
| Minute | chr | Goal minute (e.g. '90+5') |
| Score | chr | Score at goal time |
| Goalkeeper | chr | Goalkeeper beaten |
| Assist | chr | Assisting player |
| Notes | chr | Goal type ('Penalty kick', 'Free kick') |
| Result | chr | Full-time result (match log) |
| Minutes | num | Minutes played in the match |
| Gls | num | Goals scored in the match (0 allowed) |
| Opponent_Elo | num | Opponent Elo (club/national/fallback) |
| Elo_Source | chr | club / national / league_avg / global_1500 |
| Competition_Stage | chr | Group / Knockout / Final / Qualifying / Other |
| Is_Away | lgl | TRUE if venue Away |
| Difficulty_Score | num | FAMD Dim 1, standardized (higher = harder) |
| xg | num | Expected goals of the shot (Understat; NA if missing) |
| xg_source | chr | understat / missing |
| Weighted_Goal | num | Difficulty_Score (the weight) |
