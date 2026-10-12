-- Lua Quiz
-- Run this file from the project folder after installing dkjson with LuaRocks.

local json_ok, json = pcall(require, "dkjson")

if not json_ok then
    io.stderr:write("Could not load dkjson. Install it with: luarocks install dkjson\n")
    os.exit(1)
end

-- These paths are relative to the folder where you run `lua main.lua`.
local topics_file = "data/topics.json"
local questions_file = "data/questions.json"
local results_file = "data/results.json"

-- Read a JSON file and convert its contents into Lua tables.
-- A missing results file is treated as an empty history; the other files are required.
local function load_json_array(path, allow_missing)
    local file, open_error = io.open(path, "r")

    if not file then
        if allow_missing then
            return {}
        end

        return nil, open_error
    end

    local contents = file:read("*a")
    file:close()

    local value, _, decode_error = json.decode(contents)
    if decode_error then
        return nil, decode_error
    end

    if type(value) ~= "table" then
        return nil, "the top-level JSON value must be an array"
    end

    return value
end

-- Print an error and stop when a required data file cannot be loaded.
local function load_required_array(path)
    local value, load_error = load_json_array(path, false)
    if not value then
        io.stderr:write(("Could not load %s: %s\n"):format(path, tostring(load_error)))
        os.exit(1)
    end

    return value
end

-- Ask for a whole-number menu choice. Blank input can select a supplied default.
local function read_choice(prompt, minimum, maximum, default_choice)
    while true do
        io.write(prompt)
        local input = io.read("*l")

        -- End-of-file usually means the player pressed Ctrl+D/Ctrl+Z to quit.
        if input == nil then
            return nil
        end

        input = input:match("^%s*(.-)%s*$")
        if input == "" and default_choice then
            return default_choice
        end

        local choice = tonumber(input)
        if choice and choice % 1 == 0 and choice >= minimum and choice <= maximum then
            return choice
        end

        print(("Please enter a number from %d to %d."):format(minimum, maximum))
    end
end

local function wait_for_enter()
    io.write("Press Enter to continue...")
    io.read("*l")
end

-- Show topic names from topics.json, then return the selected topic's ID.
local function choose_topic(topics)
    print("\nChoose a topic:")

    for index, topic in ipairs(topics) do
        print(("%d) %s"):format(index, topic.topic))
    end

    local choice = read_choice("> ", 1, #topics)
    if not choice then
        return nil
    end

    return topics[choice].topic_id
end

-- Let the player select a difficulty. Pressing Enter chooses Any by default.
local function choose_difficulty()
    local difficulties = { "simple", "intermediate", "advanced", "any" }

    print("\nChoose a difficulty:")
    print("1) Simple")
    print("2) Intermediate")
    print("3) Advanced")
    print("4) Any (default)")

    local choice = read_choice("> ", 1, #difficulties, 4)
    if not choice then
        return nil
    end

    return difficulties[choice]
end

-- The answer in JSON is zero-based; Lua's options table starts at index 1.
local function is_valid_question(question)
    if type(question) ~= "table" or type(question.options) ~= "table" then
        return false
    end

    if type(question.question) ~= "string" or type(question.answer) ~= "number" then
        return false
    end

    return question.answer % 1 == 0 and question.options[question.answer + 1] ~= nil
end

-- Filter by topic and difficulty, then randomly take up to ten without replacement.
local function choose_questions(questions, topic_id, difficulty)
    local matches = {}

    for _, question in ipairs(questions) do
        local matches_topic = question.topic_id == topic_id
        local matches_difficulty = difficulty == "any" or question.difficulty == difficulty

        if matches_topic and matches_difficulty and is_valid_question(question) then
            matches[#matches + 1] = question
        end
    end

    local chosen = {}
    local count = math.min(10, #matches)

    for _ = 1, count do
        local random_index = math.random(#matches)
        -- Removing each selected item means it cannot be chosen a second time.
        chosen[#chosen + 1] = table.remove(matches, random_index)
    end

    return chosen
end

local function ask_question(question, question_number, question_total)
    print(("\nQuestion %d of %d"):format(question_number, question_total))
    print(question.question)

    -- The code field is optional. Newlines written as \n in JSON display as line breaks.
    if type(question.code) == "string" and question.code ~= "" then
        print(question.code)
    end

    for index, option in ipairs(question.options) do
        print(("%d) %s"):format(index, option))
    end

    local selected_option = read_choice("> ", 1, #question.options)
    if not selected_option then
        return nil
    end

    -- Convert the displayed Lua index (1-based) to the answer's JSON index (0-based).
    local is_correct = selected_option - 1 == question.answer
    if is_correct then
        print("Correct!")
    else
        print("Not quite. The correct answer is:")
        print(question.options[question.answer + 1])
    end

    if type(question.explanation) == "string" and question.explanation ~= "" then
        print("\n" .. question.explanation)
    end

    return is_correct
end

-- Keep one result per answered question in memory; write them after the quiz ends.
local function make_result(question, is_correct)
    return {
        qid = tostring(question.qid),
        topic_id = question.topic_id,
        correct = is_correct and 1 or 0,
        timestamp = os.date("%Y-%m-%dT%H:%M:%S")
    }
end

local function save_results(new_results)
    local history, load_error = load_json_array(results_file, true)
    if not history then
        return nil, load_error
    end

    for _, result in ipairs(new_results) do
        history[#history + 1] = result
    end

    local encoded, encode_error = json.encode(history, { indent = true })
    if not encoded then
        return nil, encode_error
    end

    local file, open_error = io.open(results_file, "w")
    if not file then
        return nil, open_error
    end

    file:write(encoded, "\n")
    local close_ok, close_error = file:close()
    if not close_ok then
        return nil, close_error
    end

    return true
end

local function play_round(topics, questions)
    local topic_id = choose_topic(topics)
    if not topic_id then
        return false
    end

    local difficulty = choose_difficulty()
    if not difficulty then
        return false
    end

    local quiz_questions = choose_questions(questions, topic_id, difficulty)
    if #quiz_questions == 0 then
        print("\nNo valid questions match that topic and difficulty.")
        wait_for_enter()
        return true
    end

    local score = 0
    local new_results = {}

    for index, question in ipairs(quiz_questions) do
        local is_correct = ask_question(question, index, #quiz_questions)
        if is_correct == nil then
            return false
        end

        if is_correct then
            score = score + 1
        end

        new_results[#new_results + 1] = make_result(question, is_correct)
        wait_for_enter()
    end

    local percentage = math.floor(score / #quiz_questions * 100 + 0.5)
    print("\n=== Results ===")
    print(("Score: %d/%d (%d%%)"):format(score, #quiz_questions, percentage))

    local save_ok, save_error = save_results(new_results)
    if save_ok then
        print("Your answers were saved to " .. results_file .. ".")
    else
        io.stderr:write(("Could not save results: %s\n"):format(tostring(save_error)))
    end

    return true
end

local function main()
    local topics = load_required_array(topics_file)
    local questions = load_required_array(questions_file)

    if #topics == 0 then
        io.stderr:write("topics.json does not contain any topics.\n")
        os.exit(1)
    end

    -- Seed the random number generator once so each run can select different questions.
    math.randomseed(os.time())

    print("=== Lua Quiz ===")

    local keep_playing = true
    while keep_playing do
        local completed = play_round(topics, questions)
        if not completed then
            break
        end

        print("\n1) Another quiz")
        print("2) Quit")
        local choice = read_choice("> ", 1, 2)
        keep_playing = choice == 1
    end

    print("Goodbye!")
end

main()