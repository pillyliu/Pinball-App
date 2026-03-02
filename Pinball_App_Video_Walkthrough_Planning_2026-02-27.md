# Video Walkthrough Planning Document — Pinball App

## SECTION 1 — Core App Story

Pinball App helps players improve faster by combining three things in one place: league performance data, a complete machine library, and a personal practice journal. It is built for league players, casual players who want structure, and returning players who need clear next actions.

The app solves a common problem: pinball improvement data is scattered across standings sheets, rulesheets, YouTube, and personal notes. Pinball App unifies that into one workflow. You can check league stats and targets, browse machine-specific rules and playfields, then log scores, study progress, practice sessions, and mechanics work in a persistent timeline.

What makes it unique is the closed loop between reference and execution: users discover a game in Library, open rules/playfield, then immediately capture progress in Practice using Quick Entry and workspace tools. League CSV data and target benchmarks are also connected to personal tracking, so users can compare current performance against practical goals.

---

## SECTION 2 — Feature Priority Ranking

### Core Features (must show)
1. Global tab structure: `League`, `Library`, `Practice`, `About`
2. `Library List` filtering/search and opening `Library Detail`
3. `Rulesheet Reader` and `Playfield Fullscreen` access from game detail
4. `Practice Home` quick actions and destination cards
5. `Quick Entry Sheet` save flow (`Score`, `Practice`, `Study`, `Mechanics`, video progress)
6. `Game Workspace` (`Summary`, `Input`, `Log`) and score logging
7. `Journal Timeline` edit/delete flow
8. League data views: `Stats`, `Standings`, `Targets` with filters/sort
9. Local persistence behavior (practice state saved and restored)

### Secondary Features (nice to show)
1. `League Home` rotating preview cards
2. `Insights` comparisons and trend views
3. `Mechanics` skill logging and competency slider
4. Activity logging from Library interactions
5. Resume behavior between last-viewed game and Practice

### Advanced Features (longer videos only)
1. `Group Dashboard` management (`Current`/`Archived`, archive/restore/delete)
2. `Group Editor` templates, title selection, date controls, priority flags
3. `Group Title Selection Screen` with search + library filtering
4. `Practice Settings` league CSV import flow
5. Reset flow via `Reset Confirmation Dialog`
6. Data refresh/update checks for league CSV and cache metadata

---

## SECTION 3 — Screen Walkthrough Order

1. **League Home**  
Purpose: Introduce app pillars through Stats/Standings/Targets entry points.  
Key actions: Open each destination card, call out previews.

2. **Stats**  
Purpose: Show row-level score data plus machine stats panel.  
Key actions: Change filters (season/bank/player/machine), clear filters, refresh row.

3. **Standings**  
Purpose: Show ranked season standings.  
Key actions: Change season filter, explain table columns.

4. **Targets**  
Purpose: Show benchmark scores (2nd/4th/8th) by game.  
Key actions: Change sort mode, switch bank filter.

5. **Library List**  
Purpose: Browse all machines by source/sort/filter/search.  
Key actions: Search text, change source, sort, bank filter, open game card.

6. **Library Detail**  
Purpose: Show game metadata/media and outbound resources.  
Key actions: Tap `Rulesheet`, `Playfield`, `Open in YouTube`.

7. **Rulesheet Reader**  
Purpose: Read strategy content and keep progress.  
Key actions: Scroll, use progress pill, back out and resume.

8. **Playfield Fullscreen**  
Purpose: Inspect machine layout visually.  
Key actions: Pinch zoom, pan, back.

9. **Practice Home**  
Purpose: Central action hub for logging and navigation.  
Key actions: Choose source/game, tap quick actions, open destination cards.

10. **Quick Entry Sheet**  
Purpose: Fast structured data capture.  
Key actions: Switch mode, enter values, save.

11. **Game Workspace**  
Purpose: Deep game-specific workflow.  
Key actions: Switch `Summary/Input/Log`, record a score, open log item editor, save note.

12. **Journal Timeline**  
Purpose: View and maintain history of practice + activity.  
Key actions: Change filter segment, swipe edit/delete, open entry editor.

13. **Journal Entry Editor Sheet**  
Purpose: Correct/update existing records.  
Key actions: Edit fields by entry type, save.

14. **Insights**  
Purpose: Compare trends and opponent performance.  
Key actions: Choose game/opponent, refresh.

15. **Mechanics**  
Purpose: Track technical skill progression.  
Key actions: Pick skill, set competency slider, add note, log session.

16. **Group Dashboard**  
Purpose: Organize planned practice work.  
Key actions: Create/edit/archive/restore/delete group, set priority/dates.

17. **Group Editor**  
Purpose: Configure group content and behavior.  
Key actions: Name, template, title selection, flags, save.

18. **Group Title Selection Screen**  
Purpose: Add/remove games for a group.  
Key actions: Search/filter/select titles.

19. **Practice Settings**  
Purpose: Profile, league import, defaults, reset.  
Key actions: Save profile name, run league import, open reset.

20. **Reset Confirmation Dialog**  
Purpose: Protect destructive reset action.  
Key actions: Confirm/cancel.

21. **About**  
Purpose: Brief community context and outbound links.  
Key actions: Open website/Facebook links.

---

## SECTION 4 — 1 Minute Video Outline

Target runtime: **60s**

1. **0:00–0:06 — Tabs overview (`League`, `Library`, `Practice`, `About`)**  
Key points: "This app connects league stats, game reference, and practice tracking."  
Actions: Quick tab taps.

2. **0:06–0:15 — League snapshot (`Stats`, `Standings`, `Targets`)**  
Key points: "See live league performance and target benchmarks."  
Actions: Open each screen, switch one filter/sort.

3. **0:15–0:27 — Library flow (`Library List` → `Library Detail`)**  
Key points: "Find a machine fast and open its resources."  
Actions: Search game, open card, tap `Rulesheet` briefly.

4. **0:27–0:43 — Practice flow (`Practice Home` → `Quick Entry`)**  
Key points: "Log a score or study step in seconds."  
Actions: Tap quick `Score`, enter sample value, `Save`.

5. **0:43–0:54 — Workspace + Journal**  
Key points: "Everything is saved to your timeline and game workspace."  
Actions: Show `Summary/Input/Log`, then Journal list.

6. **0:54–1:00 — Close**  
Key points: "Use League for targets, Library for learning, Practice for progress."  
Actions: Return to Practice Home card view.

---

## SECTION 5 — 3 Minute Video Outline

Target runtime: **3:00**

1. **0:00–0:20 — Intro + app purpose**  
Actions: Show tabs and quick inter-tab movement.  
Talking points: Unified workflow from data to action.

2. **0:20–0:55 — League deep enough for beginners**  
Actions:  
- League Home card taps  
- Stats: set season + player filter  
- Standings: change season  
- Targets: set sort + bank  
Talking points: How league context sets improvement goals.

3. **0:55–1:30 — Library discovery and reference use**  
Actions:  
- Source/sort/bank filter in Library List  
- Search and open game  
- Tap `Rulesheet`, then back  
- Tap `Playfield` and zoom  
Talking points: Learn machine strategy before practice.

4. **1:30–2:20 — Practice quick capture**  
Actions:  
- Practice Home source/game selection  
- Open Quick Entry (Score mode) and save  
- Re-open Quick Entry (Mechanics mode) and save  
Talking points: Fast logging across score, study, practice, mechanics.

5. **2:20–2:45 — Game Workspace and Journal**  
Actions:  
- Workspace `Summary/Input/Log` switch  
- Open Journal Timeline filter segment  
- Swipe edit a record and save  
Talking points: Persistent timeline and corrections.

6. **2:45–3:00 — Wrap**  
Actions: Show Insights/Mechanics cards briefly, end on Practice Home.  
Talking points: Start in League, learn in Library, improve in Practice.

---

## SECTION 6 — 5 Minute Video Outline

Target runtime: **5:00**

1. **0:00–0:30 — Problem and positioning**  
Screens: Tabs + League Home.  
Actions: Brief app map.

2. **0:30–1:25 — League module walkthrough**  
Screens: Stats, Standings, Targets.  
Actions:  
- Stats filters: season, bank, player, machine; clear filters; refresh  
- Standings season picker  
- Targets sort selector + bank selector  
Talking points: CSV-driven data, filter-driven decisions.

3. **1:25–2:20 — Library module walkthrough**  
Screens: Library List, Library Detail, Rulesheet Reader, Playfield Fullscreen.  
Actions:  
- Search/filter/sort  
- Open details and resource links  
- Show rulesheet state and progress behavior  
- Show playfield zoom/pan  
Talking points: Reference assets tied to each game.

4. **2:20–3:35 — Practice core workflow**  
Screens: Practice Home, Quick Entry Sheet, Game Workspace.  
Actions:  
- Select source/game  
- Quick Entry: Score + Practice + Mechanics examples  
- Workspace: input buttons and log mutation  
- Save game note  
Talking points: Structured entries are persisted and reflected in workspace.

5. **3:35–4:20 — Journal + Insights + Mechanics**  
Screens: Journal Timeline, Journal Entry Editor, Insights, Mechanics.  
Actions:  
- Filter timeline categories  
- Edit and save one entry  
- Insights game/opponent pick + refresh  
- Mechanics slider + log session  
Talking points: Reflection, comparison, and skill tracking loop.

6. **4:20–4:50 — Group and settings overview**  
Screens: Group Dashboard, Group Editor, Practice Settings.  
Actions:  
- Create/edit/archive group (brief)  
- Mention league CSV import in settings  
Talking points: Planning and administration features.

7. **4:50–5:00 — Final recap**  
Screen: Practice Home + League tab.  
Actions: End with three-step habit loop.

---

## SECTION 7 — 10 Minute Video Outline

Target runtime: **10:00**

1. **0:00–0:40 — Full intro and audience framing**  
Show all root tabs.  
Explain who should use the app and expected outcomes.

2. **0:40–2:05 — League comprehensive pass**  
Screens: League Home, Stats, Standings, Targets.  
Actions:  
- Open each destination from home cards  
- Stats: all filter controls + table behavior + refresh/update check cue  
- Standings: season switching and table interpretation  
- Targets: sort modes and bank scope  
Explain: read-only league analytics and benchmark context.

3. **2:05–3:40 — Library comprehensive pass**  
Screens: Library List, Library Detail, Rulesheet Reader, Playfield Fullscreen.  
Actions:  
- Source/sort/bank/search combinations  
- Game detail buttons (`Rulesheet`, `Playfield`, `Open in YouTube`, source links)  
- Rulesheet progress save and resume behavior  
- Playfield zoom/pan  
Explain: content retrieval from local/remote candidates and activity logging.

4. **3:40–6:10 — Practice core and daily loop**  
Screens: Practice Home, Name Prompt Overlay, Quick Entry Sheet, Game Workspace.  
Actions:  
- Name prompt save/skip path  
- Quick actions by mode: Score, Study, Practice, Mechanics, video progress  
- Save flow and immediate UI refresh  
- Workspace: `Summary/Input/Log`, row edit/delete, notes  
Explain: underlying persistence updates and quick-entry memory keys.

5. **6:10–7:25 — Timeline and editing integrity**  
Screens: Journal Timeline, Journal Entry Editor Sheet.  
Actions:  
- Segment filters (`All/Study/Practice/Scores/Notes/League`)  
- Batch edit/delete mention  
- Edit single entry and save  
Explain: canonical journal updates with linked underlying entries.

6. **7:25–8:20 — Insights and Mechanics analysis**  
Screens: Insights, Mechanics.  
Actions:  
- Opponent comparison selection + refresh  
- Skill dropdown + competency slider + notes + log session  
Explain: trend interpretation and skill progression tracking.

7. **8:20–9:20 — Group planning workflows**  
Screens: Group Dashboard, Group Editor, Group Title Selection Screen.  
Actions:  
- Create group, apply template, add titles, set priority/dates, archive/restore  
Explain: structured practice planning layer.

8. **9:20–9:50 — Settings and data behavior**  
Screens: Practice Settings, Reset Confirmation Dialog.  
Actions:  
- Save profile  
- Trigger league CSV import example  
- Show protected reset confirmation  
Explain data storage: local persisted practice state, library activity log, cached CSV/JSON, remote metadata refresh checks.

9. **9:50–10:00 — Close**  
Screen: Practice Home.  
Action: summarize repeatable user habit.

---

## SECTION 8 — Full Narration Scripts

### 1 Minute Script (word-for-word)

"Pinball App is a training hub for league and casual pinball players. It combines league analytics, machine reference content, and personal practice tracking in one workflow.  
Start in League to check Stats, Standings, and Targets. You can filter performance by season, player, and machine, then use target benchmarks to set goals.  
Move to Library to find a game quickly, open its details, and jump into Rulesheet and Playfield views so you can study before you play.  
Then go to Practice. From Quick Entry, log a score, practice session, study progress, or mechanics note in seconds.  
Everything is saved to your timeline and available in each game workspace, where you can review summary metrics, add inputs, and manage your log.  
Use League for direction, Library for understanding, and Practice for consistent improvement."

### 3 Minute Script (word-for-word)

"Welcome to Pinball App. This app is designed to help you improve with a single loop: understand your league context, study the game, then log focused practice.  
You have four main tabs: League, Library, Practice, and About.

In League, start on the home screen and open Stats. Here you can filter by season, bank, player, and machine. This lets you isolate exactly where performance changes. You can also refresh data status from the timestamp row.  
In Standings, switch seasons to compare ranking and totals over time.  
In Targets, use sort and bank filters to view benchmark scores, including second, fourth, and eighth-place targets for each game.

Next, open Library. The list supports source filters, sorting, bank filters, and search. Pick a game to open Library Detail.  
From here, you can open the Rulesheet, view the Playfield in fullscreen with zoom and pan, or jump to YouTube resources. This is the learning layer before practice.

Now go to Practice, which is the daily execution layer. On Practice Home, choose your source and game, then use quick actions.  
Open Quick Entry and log a score. You can also log study progress, practice entries, video progress, and mechanics sessions. Tap Save, and your data is written immediately and reflected in the UI.

Open Game Workspace to see Summary, Input, and Log views for the selected title. Add entries from Input, review history in Log, and keep game notes.  
Then open Journal Timeline to review everything in one place. You can filter by category, edit entries, and delete incorrect records.

For deeper analysis, use Insights to compare results by game and opponent, and Mechanics to track skill competency over time.  
Pinball App keeps your workflow simple: League gives direction, Library gives context, and Practice turns that into measurable progress."

### 5 Minute Script (word-for-word)

"Pinball App is built for players who want a repeatable improvement system, not disconnected tools. It combines league performance data, game-specific reference material, and structured practice logging in a single app.

At the top level, you have four tabs: League, Library, Practice, and About.

Let’s begin in League.  
League Home is your gateway to three screens.  
In Stats, you can filter rows by season, bank, player, and machine. This is where you identify patterns and isolate performance by context. The refresh row lets you check updated data availability.  
In Standings, season filtering helps you evaluate ranking and cumulative outcomes across sessions.  
In Targets, you can sort by area, bank, or alphabetically, and filter by bank to focus your practice benchmark for each machine.

Now go to Library.  
Library List supports source selection, sorting, bank filtering, and text search. Open any game card to enter Library Detail.  
Library Detail gives you machine information and resource actions: Rulesheet, Playfield, and external video links.  
Open Rulesheet Reader to review strategy content. This screen handles loading, missing, and error states, and can save viewing progress for resume behavior.  
Open Playfield Fullscreen to inspect shot geometry with pinch zoom and panning.

Next is Practice, where your training record lives.  
On Practice Home, select a library source and a game, then launch quick actions. If a profile name is missing, the name prompt appears and can optionally enable league import setup.  
Open Quick Entry. This sheet supports multiple modes: Score, Rulesheet progress, Tutorial video, Gameplay video, Practice, and Mechanics.  
For score mode, enter score and context and save.  
For mechanics mode, choose a skill, set competency, add notes, and save.  
Each save writes to persisted practice state and updates journal history.

Open Game Workspace for the selected game.  
Summary shows next actions and stats context.  
Input provides direct buttons for Rulesheet, Playfield, Score, Tutorial, Practice, and Gameplay actions.  
Log shows game-specific history with edit and delete actions.  
You can also save game notes and open related resources from here.

Now open Journal Timeline.  
This view merges practice journal entries and library activity and supports category filters: All, Study, Practice, Scores, Notes, and League.  
Use row actions to edit or delete entries, then save changes from the entry editor sheet.

For advanced analysis, open Insights. Select a game and opponent and refresh to review comparisons and trends.  
In Mechanics, choose a skill, adjust competency, add a note, and log the session to track progression over time.

For planning workflows, open Group Dashboard and Group Editor. You can create and manage practice groups, set active or archived state, configure priority, and assign titles.  
Finally, Practice Settings lets you maintain your profile, trigger league CSV import, set defaults, and access reset with confirmation safeguards.

The core habit is straightforward: check League to set goals, use Library to study, then log execution in Practice. Repeating that cycle is how the app turns activity into measurable improvement."

### 10 Minute Script (word-for-word)

"Welcome to this full tutorial of Pinball App.  
This app is designed for players who want a disciplined improvement loop. Instead of switching between standings spreadsheets, rules pages, videos, and separate notes, everything is connected in one system.

At the root, there are four tabs: League, Library, Practice, and About.  
League is where you understand performance context.  
Library is where you learn each machine.  
Practice is where you record execution and track progress.  
About provides league information and external links.

Let’s start with League.  
On League Home, you have destination cards for Stats, Standings, and Targets, with preview content that helps you jump into the right view quickly.  
Open Stats. This screen shows row-level score data and a machine stats panel. Use filters for season, bank, player, and machine. As filters change, the data table and computed stats update immediately in memory. The refresh row lets you trigger a data refresh check.  
Now open Standings. This screen focuses on ranked season standings. Change the season picker to compare outcomes over time and read totals and bank-level context.  
Next open Targets. This screen shows benchmark scores, including second, fourth, and eighth-place target values. Use sort mode and bank filters to reorder and scope the table.  
The important point in League is that these views are analytics-driven and read league datasets without writing persistent user records.

Now move to Library.  
Open Library List. You can choose source, sort order, bank filter, and search text. This gives you fast access when you want one specific title or when you want to browse by venue structure.  
Open a game card into Library Detail.  
Here you can launch Rulesheet, Playfield, and external video resources.  
Open Rulesheet Reader. Scroll through the content, then use progress actions so your position can be resumed later. This reader also handles missing or unavailable rulesheet states gracefully.  
Go back and open Playfield Fullscreen. Pinch to zoom and pan across the table image to inspect shots, lanes, and layout.  
Then return to detail and briefly show external resource links.  
Library interactions are also captured as activity events, which later appear in timeline views.

Now open Practice, the core execution area.  
Practice Home is a launch pad. You can choose source and game, access quick actions, resume recent context, and jump to destination cards like Group Dashboard, Journal, Insights, and Mechanics.  
If no player name is configured, the name prompt overlay appears. Enter a name and optionally enable league import setup. Save or skip to continue.

Open Quick Entry.  
This sheet supports several entry types: score logging, study progress, tutorial and gameplay video progress, practice sessions, and mechanics logs.  
First, demonstrate Score mode. Enter a sample score and context, then save.  
Next, demonstrate Practice or Study mode with a short note.  
Then show Mechanics mode: pick a skill, set competency with the slider, add note, and save.  
Each save updates persisted practice state and journal records, then refreshes UI.

Now open Game Workspace.  
Use the mode selector to switch between Summary, Input, and Log.  
In Summary, call out next action and progress context.  
In Input, show action buttons for Rulesheet, Playfield, Score, Tutorial, Practice, and Gameplay entries.  
In Log, show existing entries, then edit or delete one record.  
Also demonstrate saving a game note.  
This workspace is where users stay focused on one machine while seeing reference and history together.

Next, open Journal Timeline.  
This view combines practice data and library activity with filters for All, Study, Practice, Scores, Notes, and League.  
Switch filters to show how timeline scope changes.  
Open one row in the Journal Entry Editor Sheet, update fields, and save.  
This demonstrates that updates propagate to canonical journal data and corresponding underlying entries.

Now open Insights.  
Choose a game and opponent, then refresh.  
Explain that this view helps users compare outcomes and identify competitive gaps using available local and league-derived context.

Open Mechanics.  
Select a skill, adjust competency, add a short note, and log the mechanics session.  
This creates a trackable skill history and keeps technique training visible, not just score outcomes.

Now cover practice planning features.  
Open Group Dashboard.  
Show current versus archived segmentation, create action, and row-level archive or restore behavior.  
Open Group Editor.  
Set a group name, choose a template option, add titles through the title selection flow, set priority and date controls, then save.  
Open Group Title Selection Screen and demonstrate search plus selection toggles.  
These features support structured training plans beyond ad hoc practice.

Finally, open Practice Settings.  
Show profile name editing and save.  
Demonstrate league import selection and import action, which maps eligible CSV rows into practice records with dedupe handling.  
Show reset entry point and open Reset Confirmation Dialog to emphasize protection around destructive actions.

To close, return to Practice Home and summarize the operating model:  
Use League to identify what matters, use Library to study how to execute, and use Practice to capture what happened.  
Over time, this creates a persistent, searchable training record tied to actual machines and league context.  
That is the core value of Pinball App."

---

## SECTION 9 — Recording Plan

1. **Pre-record setup**
- Use seeded realistic data for League tables and Practice history.
- Preselect one representative game that has rulesheet, playfield, and video links.
- Prepare one practice group and one existing journal entry for edit demonstration.

2. **Capture order (recommended)**
- Record global tab flyover first.
- Record League module in one continuous take.
- Record Library module in one continuous take.
- Record Practice core (`Home`, `Quick Entry`, `Workspace`, `Journal`) in one take.
- Record advanced add-ons (`Insights`, `Mechanics`, `Group`, `Settings`) in separate clips.
- Record About screen last as optional closing clip.

3. **Zoom/highlight strategy**
- Highlight filter controls at first use (Stats, Standings, Targets, Library).
- Zoom on `Save` actions in Quick Entry and Journal Editor.
- Zoom on segmented mode switches (`Summary/Input/Log`, timeline filters).
- Highlight destructive/critical actions (`Reset`, delete row actions) with slower pacing.

4. **Pacing targets**
- 1-minute cut: 1 action per screen max.
- 3-minute cut: 2–3 actions per module.
- 5-minute cut: complete happy paths plus one edit flow.
- 10-minute cut: happy path + advanced management + settings/import explanation.

5. **Transitions**
- Use hard cuts between tabs for speed.
- Use short cross-dissolve when moving from Library study to Practice logging to reinforce workflow continuity.
- Keep on-screen labels for screen names during first appearance.

---

## SECTION 10 — Visual Emphasis Suggestions

1. **Always show**
- Tab bar changes (`League` → `Library` → `Practice`).
- Filter changes and immediate table/list updates.
- Save confirmations and resulting list/timeline updates.

2. **Highlight strongly**
- Quick Entry mode selector and `Save`.
- Workspace mode switch (`Summary`, `Input`, `Log`).
- Journal filter segmented control.
- Group archive/restore and save actions in editor.
- Practice Settings import action entry point.

3. **Zoom in on**
- Stats filter panel and clear filters.
- Library search/source/sort controls.
- Rulesheet progress/resume affordance.
- Mechanics competency slider.
- Reset confirmation dialog text/action.

4. **Clarity rules for first-time users**
- Keep one focal interaction visible at a time.
- Pause briefly after each save to show outcome state.
- Verbally name the current screen on first entry.
- Avoid fast scrolling during explanation segments.
- End each module with “what this is for” before transitioning.
