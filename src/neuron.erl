%%%-------------------------------------------------------------------
%%% @author amiryt
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. ספט׳ 2020 20:04
%%%-------------------------------------------------------------------
-module(neuron).
-author("amiryt").

-behaviour(gen_statem).

%% API
-export([start/0, start_link/2]).

%% Callback functions
-export([init/1, format_status/2, state_name/3, handle_event/4, terminate/3,
  code_change/4, callback_mode/0]).
%% States functions
-export([active/3]).

%% Events functions
-export([new_data/1, change_parameters/1, change_weights/1]).

-define(SERVER, ?MODULE).

-record(neuron_state, {dt, simulation_time, time_list, t_rest, vm, rm, cm, tau_m, tau_ref, vth, v_spike, i_app, weights, i_synapse}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Creates a gen_statem process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%% TODO: Support restore & regular init!!
%% OperationMode: restore or regular
start_link(OperationMode, NeuronParameters) ->
  gen_statem:start_link({local, ?SERVER}, ?MODULE, [OperationMode, NeuronParameters], []).

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

%% @private
%% @doc Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize from ets of the layer
%%init([restore, EtsId]) ->
%%  process_flag(trap_exit, true),
%%  {ok, state_name, #neuron_state{}};

%% @private
%% @doc Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize the new parameters
init([regular, NeuronParametersMap]) ->
  process_flag(trap_exit, true),
  io:format("New neuron has started! setting his parameters"),
  Dt = maps:get(dt, NeuronParametersMap),
  T = maps:get(simulation_time, NeuronParametersMap),
  Time = arange(0, T + Dt, Dt),
  T_rest = maps:get(t_rest, NeuronParametersMap),
  Vm = maps:get(vm, NeuronParametersMap),
  Rm = maps:get(rm, NeuronParametersMap),
  Cm = maps:get(cm, NeuronParametersMap),
  Tau_m = maps:get(tau_m, NeuronParametersMap),
  Tau_ref = maps:get(tau_ref, NeuronParametersMap),
  Vth = maps:get(vth, NeuronParametersMap),
  V_spike = maps:get(v_spike, NeuronParametersMap),
  I_app = maps:get(i_app, NeuronParametersMap),
  Weights = list_same(1, length(Time)),
  I_synapse = list_same(0, length(Time)),
  {ok, active, #neuron_state{dt = Dt, simulation_time = T, time_list = Time, t_rest = T_rest, vm = Vm, rm = Rm, cm = Cm, tau_m = Tau_m, tau_ref = Tau_ref,
    vth = Vth, v_spike = V_spike, i_app = I_app, weights = Weights, i_synapse = I_synapse}}.

%% @private
%% @doc This function is called by a gen_statem when it needs to find out
%% the callback mode of the callback module.
callback_mode() ->
  state_functions.

%% @private
%% @doc Called (1) whenever sys:get_status/1,2 is called by gen_statem or
%% (2) when gen_statem terminates abnormally.
%% This callback is optional.
format_status(_Opt, [_PDict, _StateName, _State]) ->
  Status = some_term,
  Status.

%% @private
%% @doc There should be one instance of this function for each possible
%% state name.  If callback_mode is state_functions, one of these
%% functions is called when gen_statem receives and event from
%% call/2, cast/2, or as a normal process message.
state_name(_EventType, _EventContent, State = #neuron_state{}) ->
  NextStateName = next_state,
  {next_state, NextStateName, State}.

%% TODO: Copy that 4 times: weights_change, new_data, change_parameters, _Others for the start

%% Event of new current
active(cast, {new_data, I_input}, State = #neuron_state{dt = Dt, simulation_time = T, time_list = Time, t_rest = T_rest, vm = Vm, rm = Rm, cm = Cm, tau_m = Tau_m, tau_ref = Tau_ref,
  vth = Vth, v_spike = V_spike, i_app = I_app, weights = Weights}) ->
  io:format("Event of new data"),
  I_synapse = mapMult(I_input, Weights), % The current depends on the current of all the other connected neurons and their weights
%%  lif model here (with I synapse)
  {next_state, active, State};

%% Event of changing parameters
active(cast, {change_parameters, NewParametersMap}, State = #neuron_state{}) ->
  io:format("Event of parameters"),
  Dt = maps:get(dt, NewParametersMap),
  T = maps:get(simulation_time, NewParametersMap),
  Time = arange(0, T + Dt, Dt),
  T_rest = maps:get(t_rest, NewParametersMap),
  Vm = maps:get(vm, NewParametersMap),
  Rm = maps:get(rm, NewParametersMap),
  Cm = maps:get(cm, NewParametersMap),
  Tau_m = maps:get(tau_m, NewParametersMap),
  Tau_ref = maps:get(tau_ref, NewParametersMap),
  Vth = maps:get(vth, NewParametersMap),
  V_spike = maps:get(v_spike, NewParametersMap),
  I_app = maps:get(i_app, NewParametersMap),
  Weights = list_same(1, length(Time)),
  I_synapse = list_same(0, length(Time)),
  {next_state, active, State#neuron_state{dt = Dt, simulation_time = T, time_list = Time, t_rest = T_rest, vm = Vm, rm = Rm, cm = Cm, tau_m = Tau_m, tau_ref = Tau_ref,
    vth = Vth, v_spike = V_spike, i_app = I_app, weights = Weights, i_synapse = I_synapse}};

%% Event of changing weights
%%TODO: Change this when we have the correct equation
active(cast, {change_weights}, State = #neuron_state{weights = Old_Weights}) ->
  io:format("Event of weights"),
%%  back propagation function here
  New_Weights = Old_Weights,
  {next_state, active, State#neuron_state{weights = New_Weights}};

%% Any other event - just flush it from the mailbox
active(cast, _Other, State = #neuron_state{}) ->
  io:format("Waiting in active state"),
  {next_state, active, State}.


%% @private
%% @doc If callback_mode is handle_event_function, then whenever a
%% gen_statem receives an event from call/2, cast/2, or as a normal
%% process message, this function is called.
handle_event(_EventType, _EventContent, _StateName, State = #neuron_state{}) ->
  NextStateName = the_next_state_name,
  {next_state, NextStateName, State}.

%% Layer functions for neuron
new_data(I) -> gen_statem:cast(?MODULE, {active, new_data, I}).
change_parameters(Parameters) -> gen_statem:cast(?MODULE, {active, change_parameters, Parameters}).
change_weights(Weights) -> gen_statem:cast(?MODULE, {active, change_weights, Weights}).

%% @private
%% @doc This function is called by a gen_statem when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_statem terminates with
%% Reason. The return value is ignored.
terminate(_Reason, _StateName, _State = #neuron_state{}) ->
  ok.

%% @private
%% @doc Convert process state when code is changed
code_change(_OldVsn, StateName, State = #neuron_state{}, _Extra) ->
  {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

start() ->
%%  {ok, Pid} = neuron:start_link(),
%%  sys:trace(Pid, true),
  Dt = 0.125,
  L = arange(0, 50 + Dt, Dt),
%%  L1 = mapMult([1,2,3], [4,5,6]),
  hey.

%% TODO: Create the lif function using the record !!

%% @doc  Receives: Start - The number we start
%%                End - The number we end
%%                Dt - The size of the jumps
%%      Returns:  List aranged (like in python)
arange(Start, End, Dt) ->
  NumLoops = math:ceil((End - Start) / Dt),
  arangeLoop(Start, Dt, NumLoops).
arangeLoop(_, _, Finish) when (Finish == 0) ->
  [];
arangeLoop(Start, Dt, Rounds) ->
  [Start | arangeLoop(Start + Dt, Dt, Rounds - 1)].

%% @doc  Receives: Num - The number we want
%%                Len - Number of times that "Num" would appear
%%      Returns:  A list with the same elements Len times
list_same(_, 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].

%% @doc  Receives: L1 - List 1 [1, 2, 3]
%%                             Arg2 - List 2 [4, 5, 6]
%%      Returns:  A list of their mult [4, 10, 18]
mapMult(List1, []) ->
  lists:map(fun(X) -> (X) end, List1);
mapMult(List1, Args2) when ((not is_list(Args2)) and is_number(Args2)) ->
  lists:map(fun(X) -> (X - Args2) end, List1);
mapMult(List1, Args2) when (is_list(Args2) and is_list(Args2)) ->
  mapMultLoop(List1, Args2, length(List1), length(Args2)).
mapMultLoop(_, _, List1length, Args2length) when List1length =/= Args2length ->
  lenError;
mapMultLoop(List1, Args2, List1length, Args2length) when List1length =:= Args2length ->
  lists:map(fun(X) -> hd(X) * hd(tl(X)) end, listsToCouple(List1, Args2, [])).

%% @doc  Receives: L1 - List 1 [1, 2, 3]
%%                             L2 - List 2 [4, 5, 6]
%%      Returns:  A list of couples [[1, 4], [2, 5], [3, 6]]
listsToCouple([], [], Acc) ->
  lists:reverse(Acc);
listsToCouple([H1|T1], [H2|T2], Acc) ->
  listsToCouple(T1, T2, [[H1|[H2]]|Acc]).