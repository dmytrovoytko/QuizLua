# QuizLua

A beginner-friendly multiple-choice quiz app written in Lua. It loads topics and questions from JSON files, explains each answer, and saves answer history to JSON.

## Requirements

- Lua 5.1 or newer
- LuaRocks
- The `dkjson` library

Install the JSON library:

```sh
luarocks install dkjson
```

Run the app from the project folder so its relative `data/` paths resolve:

```sh
lua main.lua
```

## Specification

1. Display topics from `data/topics.json` and let the player choose one.
2. Let the player choose simple, intermediate, advanced, or any difficulty. Pressing Enter selects any.
3. Filter questions by the selected `topic_id` and difficulty, then select up to 10 at random without repeats. If fewer than 10 match, use all matching questions.
4. Show each question, its optional code snippet, and numbered answer options. Choices are entered as `1`, `2`, `3`, and so on.
5. Check the answer, show whether it was correct, and display the explanation immediately. Invalid input prompts the player again.
6. Show progress and the final score as both a fraction and percentage.
7. At the end of a completed quiz, append one result record per question to `data/results.json`.
8. Offer another quiz or quit.

The JSON `answer` value is zero-based to match the question data convention. Lua tables are one-based, so the app adds one when looking up the correct option. For example, `answer: 1` identifies the second option.

## Terminal flow example

```text
=== Lua Quiz ===

Choose a topic:
1) Lua basics: chunks, comments, variables, types
2) Loops and conditionals
3) Tables
> 1

Choose difficulty:
1) Simple
2) Intermediate
3) Advanced
4) Any [default]
> [Enter]

Question 1 of 10
How do you write a single-line comment in Lua?

-- this is a comment
-- print("hi")

1) # this is a comment
2) -- this is a comment
3) // this is a comment
4) <!-- this is a comment -->
> 2

Correct!
Lua uses -- for single-line comments...
Press Enter to continue.

...

=== Results ===
Score: 8/10 (80%)
1) Another quiz
2) Quit
>
```

On invalid choices flow would show a brief error and repeat the prompt.

## Project Files

```text
main.lua                 # Quiz menus, question flow, scoring, and JSON persistence
data/topics.json         # Topic IDs and display names
data/questions.json      # Question bank
data/results.json        # Persistent answer history
```

`README.md` is the project documentation in Markdown. Quiz content and saved results use JSON.

## Data Formats

### Topics

`data/topics.json` is a JSON array. Each `topic_id` connects a topic to its questions:

```json
[
	{"topic_id": 1, "topic": "Lua basics: chunks, comments, variables, types"},
	{"topic_id": 2, "topic": "Loops and conditionals: if, while, repeat, for"},
	{"topic_id": 3, "topic": "Tables: arrays, dictionaries, iteration"}
]
```

### Questions

`data/questions.json` is an array of question objects. The `code` field is optional; use `\n` inside its JSON string to represent line breaks.

```json
[
	{
		"qid": "101",
		"topic_id": 1,
		"question": "How do you write a single-line comment in Lua? (Python uses #)",
		"code": "-- this is a comment\n-- print(\"hi\")",
		"options": [
			"# this is a comment",
			"-- this is a comment",
			"// this is a comment",
			"<!-- this is a comment -->"
		],
		"answer": 1,
		"explanation": "Lua uses -- for single-line comments.",
		"difficulty": "simple"
	}
]
```

The `answer` is a zero-based option index: `0` is the first option, `1` is the second, and so on. Difficulty must be `simple`, `intermediate`, or `advanced`. Choosing any includes all difficulties.

### Results

`data/results.json` starts as an empty array (`[]`). The app preserves prior entries and adds one record for every question answered in a completed quiz:

```json
[
	{
		"qid": "101",
		"topic_id": 1,
		"correct": 1,
		"timestamp": "2026-10-05T13:48:03"
	}
]
```

`correct` is the number `1` for a correct answer or `0` for an incorrect answer. Timestamps use the computer's local time in `YYYY-MM-DDTHH:MM:SS` format.