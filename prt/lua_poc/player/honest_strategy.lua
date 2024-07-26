local constants = require "constants"
local helper = require "utils.helper"

local Machine = require "computation.machine"

local HonestStrategy = {}
HonestStrategy.__index = HonestStrategy

function HonestStrategy:new(commitment_builder, machine_path, sender)
    local honest_strategy = {
        commitment_builder = commitment_builder,
        machine_path = machine_path,
        sender = sender
    }

    setmetatable(honest_strategy, self)
    return honest_strategy
end

function HonestStrategy:_join_tournament(tournament, commitment)
    local f, left, right = commitment:children(commitment.root_hash)
    assert(f)
    local last, proof = commitment:last()

    helper.log_timestamp(string.format(
        "join tournament %s of level %d with commitment %s",
        tournament.address,
        tournament.level,
        commitment.root_hash
    ))
    local ok, e = self.sender:tx_join_tournament(
        tournament.address,
        last,
        proof,
        left,
        right
    )
    if not ok then
        helper.log_timestamp(string.format(
            "join tournament reverted: %s",
            e
        ))
    end
end

function HonestStrategy:_react_match(state, match, commitment)
    -- TODO call timeout if needed

    helper.log_timestamp("Enter match at HEIGHT: " .. match.current_height)
    if match.current_height == 0 then
        -- match sealed
        if match.tournament.level == (match.tournament.max_level - 1) then
            local f, left, right = commitment.root_hash:children()
            assert(f)

            helper.log_timestamp(string.format(
                "Calculating access logs for step %s",
                match.running_leaf
            ))

            local cycle = match.base_big_cycle
            local ucycle = (match.leaf_cycle & constants.uarch_span):touinteger()
            local logs = Machine:get_logs(self.machine_path, cycle, ucycle)

            helper.log_timestamp(string.format(
                "win leaf match in tournament %s of level %d for commitment %s",
                match.tournament.address,
                match.tournament.level,
                commitment.root_hash
            ))
            local ok, e = self.sender:tx_win_leaf_match(
                match.tournament.address,
                match.commitment_one,
                match.commitment_two,
                left,
                right,
                logs
            )
            if not ok then
                helper.log_timestamp(string.format(
                    "win leaf match reverted: %s",
                    e
                ))
            end
        elseif match.inner_tournament then
            return self:_react_tournament(state, match.inner_tournament)
        end
    elseif match.current_height == 1 then
        -- match to be sealed
        local found, left, right = match.current_other_parent:children()
        if not found then
            return
        end

        local agree_state, agree_state_proof
        if match.running_leaf:iszero() then
            agree_state, agree_state_proof = commitment.implicit_hash, {}
        else
            agree_state, agree_state_proof = commitment:prove_leaf(match.running_leaf - 1)
        end

        if match.tournament.level == (match.tournament.max_level - 1) then
            helper.log_timestamp(string.format(
                "seal leaf match in tournament %s of level %d for commitment %s",
                match.tournament.address,
                match.tournament.level,
                commitment.root_hash
            ))
            local ok, e = self.sender:tx_seal_leaf_match(
                match.tournament.address,
                match.commitment_one,
                match.commitment_two,
                left,
                right,
                agree_state,
                agree_state_proof
            )
            if not ok then
                helper.log_timestamp(string.format(
                    "seal leaf match reverted: %s",
                    e
                ))
            end
        else
            helper.log_timestamp(string.format(
                "seal inner match in tournament %s of level %d for commitment %s",
                match.tournament.address,
                match.tournament.level,
                commitment.root_hash
            ))
            local ok, e = self.sender:tx_seal_inner_match(
                match.tournament.address,
                match.commitment_one,
                match.commitment_two,
                left,
                right,
                agree_state,
                agree_state_proof
            )
            if not ok then
                helper.log_timestamp(string.format(
                    "seal inner match reverted: %s",
                    e
                ))
            end
        end
    else
        -- match running
        local found, left, right = match.current_other_parent:children()
        if not found then
            helper.log_timestamp("not my turn to react")
            return
        end

        local new_left, new_right
        if left ~= match.current_left then
            local f
            f, new_left, new_right = left:children()
            assert(f)

            helper.log_timestamp("going down to the left")
        else
            local f
            f, new_left, new_right = right:children()
            assert(f)

            helper.log_timestamp("going down to the right")
        end

        helper.log_timestamp(string.format(
            "advance match with current height %d in tournament %s of level %d for commitment %s",
            match.current_height,
            match.tournament.address,
            match.tournament.level,
            commitment.root_hash
        ))
        local ok, e = self.sender:tx_advance_match(
            match.tournament.address,
            match.commitment_one,
            match.commitment_two,
            left,
            right,
            new_left,
            new_right
        )
        if not ok then
            helper.log_timestamp(string.format(
                "advance match reverted: %s",
                e
            ))
        end
    end
end

function HonestStrategy:_react_tournament(state, tournament)
    helper.log_timestamp("Enter tournament at address: " .. tournament.address)
    local commitment = self.commitment_builder:build(
        tournament.base_big_cycle,
        tournament.level,
        tournament.log2_stride,
        tournament.log2_stride_count
    )

    state.hero_state.tournament = tournament
    state.hero_state.commitment = commitment

    local tournament_winner = tournament.tournament_winner
    if tournament_winner[1] == "true" then
        if not tournament.parent then
            helper.log_timestamp("TOURNAMENT FINISHED, HURRAYYY")
            helper.log_timestamp("Winner commitment: " .. tournament_winner[2]:hex_string())
            helper.log_timestamp("Final state: " .. tournament_winner[3]:hex_string())
            return true
        else
            local old_commitment = self.commitment_builder:build(
                tournament.parent.base_big_cycle,
                tournament.parent.level,
                tournament.parent.log2_stride,
                tournament.parent.log2_stride_count
            )
            if tournament_winner[2] ~= old_commitment.root_hash then
                helper.log_timestamp("player lost tournament")
                return true
            end

            if tournament.commitments[commitment.root_hash].called_win then
                helper.log_timestamp("player already called winInnerMatch")
                return
            else
                tournament.commitments[commitment.root_hash].called_win = true
            end

            helper.log_timestamp(string.format(
                "win tournament %s of level %d for commitment %s",
                tournament.address,
                tournament.level,
                commitment.root_hash
            ))
            local _, left, right = old_commitment:children(old_commitment.root_hash)
            local ok, e = self.sender:tx_win_inner_match(
                tournament.parent.address,
                tournament.address,
                left,
                right
            )
            if not ok then
                helper.log_timestamp(string.format(
                    "win inner match reverted: %s",
                    e
                ))
            end
            return
        end
    end

    if not tournament.commitments[commitment.root_hash] then
        self:_join_tournament(tournament, commitment)
    else
        local commitment_clock = tournament.commitments[commitment.root_hash].status.clock
        helper.log_timestamp(tostring(commitment_clock))

        local latest_match = tournament.commitments[commitment.root_hash].latest_match
        state.hero_state.latest_match = latest_match
        if latest_match then
            return self:_react_match(state, latest_match, commitment)
        end
    end
end

function HonestStrategy:react(state)
    return self:_react_tournament(state, state.root_tournament)
end

return HonestStrategy
