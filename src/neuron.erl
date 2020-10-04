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
-export([start/0, start_link/4]).

%% Callback functions
-export([init/1, format_status/2, state_name/3, handle_event/4, terminate/3,
  code_change/4, callback_mode/0]).
%% States functions
-export([active/3, stop/3]).

%% Events functions
-export([new_data/3, change_parameters/3, change_weights/3, determine_output/4, stop_neuron/1]).

-define(SERVER, ?MODULE).

-record(neuron_state, {dt, simulation_time, time_list, t_rest, vm, rm, cm, tau_m, tau_ref, vth, v_spike, i_app, weights, i_synapse, neuron_pid, output_result}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc Creates a gen_statem process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%% TODO: Support restore & regular init!!
%% OperationMode: restore or regular
start_link(Neuron_Number, OperationMode, NeuronPid, NeuronParameters) ->
  gen_statem:start_link({local, gen_Name("neuron", Neuron_Number)}, ?MODULE, [OperationMode, Neuron_Number, NeuronPid, NeuronParameters], []).

%%%===================================================================
%%% gen_statem callbacks
%%%===================================================================

%% @private
%% @doc Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize from ets of the layer
%%init([restore, EtsId]) ->
%%  io:format("Neuron(init): The neuron has restored his parameters from the backup in the layer!~n"),
%%  process_flag(trap_exit, true),
%%  {ok, state_name, #neuron_state{}};

%% @private
%% @doc Whenever a gen_statem is started using gen_statem:start/[3,4] or
%% gen_statem:start_link/[3,4], this function is called by the new
%% process to initialize the new parameters
init([regular, Neuron_Number, NeuronPid, NeuronParametersMap]) ->
  process_flag(trap_exit, true),
  io:format("Neuron(init): Neuron ~p has started! setting his parameters~n", [Neuron_Number]),
  Dt = maps:get(dt, NeuronParametersMap),
  T = maps:get(simulation_time, NeuronParametersMap),
  Time = arange(0, T + Dt, Dt),
  T_rest = maps:get(t_rest, NeuronParametersMap),
  Vm = list_same(0, length(Time)),
  Rm = maps:get(rm, NeuronParametersMap),
  Cm = maps:get(cm, NeuronParametersMap),
  Tau_m = Rm * Cm,
  Tau_ref = maps:get(tau_ref, NeuronParametersMap),
  Vth = maps:get(vth, NeuronParametersMap),
  V_spike = maps:get(v_spike, NeuronParametersMap),
  I_app = maps:get(i_app, NeuronParametersMap),
  Weights = list_same(1, length(Time)),
  I_synapse = list_same(0, length(Time)),
  Output_Result = {-1000, -1000}, % Random value in order to help us find the maximal result
  {ok, active, #neuron_state{dt = Dt, simulation_time = T, time_list = Time, t_rest = T_rest, vm = Vm, rm = Rm, cm = Cm, tau_m = Tau_m, tau_ref = Tau_ref,
    vth = Vth, v_spike = V_spike, i_app = I_app, weights = Weights, i_synapse = I_synapse, neuron_pid = NeuronPid, output_result = Output_Result}}.

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

%% Event of sending output
active(cast, {output_path, Manager_Pid, Input_Len, Value}, State = #neuron_state{output_result = {Left, Max_Value}}) ->
  io:format("Neuron(active): Event of output~n"),
  if
    Left == -1000 ->
      case Input_Len == 1 of % Only one neuron in the input layer, that means we need to send the value now
        true ->
          Temp_Left = Left,
          Temp_Max = Max_Value, % First time
%%          TODO: Change every "neuron_pid" HERE to the output computer node and pid
          State#neuron_state.neuron_pid ! {maximal_amount, Manager_Pid, Value};
        false ->
          Temp_Left = Input_Len - 1,
          Temp_Max = Value % First time
      end,
      New_Left = Temp_Left,
      New_Max = Temp_Max;
    Left == 1 -> New_Left = -1000,
      New_Max = -1000, % Reset after we finish
      State#neuron_state.neuron_pid ! {maximal_amount, Manager_Pid, Max_Value};
    Value > Max_Value -> New_Left = Left - 1,
      New_Max = Value; % New maximal amount of spikes
    true -> New_Left = Left - 1,
      New_Max = Max_Value % The previous amount of spikes was bigger
  end,
  io:format("Neuron Old: ~p New: ~p~n", [New_Max, Max_Value]),
  {next_state, active, State#neuron_state{output_result = {New_Left, New_Max}}};

%% Event of changing weights
active(cast, {change_weights, Manager_Pid, User_Weights}, State = #neuron_state{}) ->
  io:format("Neuron(active): Event of weights~n"),
%%  back propagation function here
  New_Weights = User_Weights,
  io:format("Old: ~p~n", [State#neuron_state.weights]),
  io:format("New: ~p~n", [New_Weights]),
  Manager_Pid ! {neuron_finished}, % Inform the main process that this neuron finished the function
%%  State#neuron_state.neuron_pid ! finished_setting_weights,
  {next_state, active, State#neuron_state{weights = New_Weights}};


%% Event of new current
active(cast, {new_data, Manager_Pid, I_input}, State = #neuron_state{neuron_pid = Neuron_Pid, weights = Weights}) ->
  io:format("Neuron(active): Event of new data~n"),
  I_synapses = synapses(I_input, Weights), % The current depends on the current of all the other connected neurons and their weights
  Results = [lif(X, State#neuron_state.time_list, State, 0, []) || X <- I_synapses],
  Spike_trains = [returnFromElem(R, spike_train) || R <- Results],
  Vm = [lists:sublist(R, 1, findElemLocation(R, spike_train, 1) - 1) || R <- Results],
%%  io:format("Vm neuron: ~p", [Vm]),
%%  Manager_Pid ! {neuron_finished}, % Inform the main process that this neuron finished the function
  Neuron_Pid ! {spikes_from_neuron, Manager_Pid, Spike_trains},
  {next_state, active, State#neuron_state{vm = Vm}};

%% Event of changing parameters
active(cast, {change_parameters, Manager_Pid, NewParametersMap}, State = #neuron_state{}) ->
  io:format("Neuron(active): Event of parameters~n"),
  Dt = maps:get(dt, NewParametersMap),
  T = maps:get(simulation_time, NewParametersMap),
  Time = arange(0, T + Dt, Dt),
  T_rest = maps:get(t_rest, NewParametersMap),
  Vm = State#neuron_state.vm,
  Rm = maps:get(rm, NewParametersMap),
  Cm = maps:get(cm, NewParametersMap),
  Tau_m = Rm * Cm,
  Tau_ref = maps:get(tau_ref, NewParametersMap),
  Vth = maps:get(vth, NewParametersMap),
  V_spike = maps:get(v_spike, NewParametersMap),
  I_app = maps:get(i_app, NewParametersMap),
  Weights = State#neuron_state.weights,
  I_synapse = State#neuron_state.i_synapse,
  Manager_Pid ! {neuron_finished}, % Inform the main process that this neuron finished the function
%%  State#neuron_state.neuron_pid ! finished_setting_parameters,
  {next_state, active, State#neuron_state{dt = Dt, simulation_time = T, time_list = Time, t_rest = T_rest, vm = Vm, rm = Rm, cm = Cm, tau_m = Tau_m, tau_ref = Tau_ref,
    vth = Vth, v_spike = V_spike, i_app = I_app, weights = Weights, i_synapse = I_synapse}};


%% We need to stop the neuron
active(cast, {stop}, State = #neuron_state{}) ->
  io:format("Neuron(active): We need to stop neuron~n"),
  {next_state, stop, State};

%% Any other event - just flush it from the mailbox
active(cast, _Other, State = #neuron_state{}) ->
  io:format("Neuron(active): Waiting~n"),
  {next_state, active, State}.

%% Any other event - just flush it from the mailbox
stop(cast, _Other, State = #neuron_state{}) ->
  io:format("Waiting in stop state~n"),
  {next_state, stop, State}.


%% @private
%% @doc If callback_mode is handle_event_function, then whenever a
%% gen_statem receives an event from call/2, cast/2, or as a normal
%% process message, this function is called.
handle_event(_EventType, _EventContent, _StateName, State = #neuron_state{}) ->
  NextStateName = the_next_state_name,
  {next_state, NextStateName, State}.


%% Layer functions for neuron
new_data(I, Pid_Manager, Neuron_Number) ->
  gen_statem:cast(gen_Name("neuron", Neuron_Number), {new_data, Pid_Manager, I}).
change_parameters(Parameters, Manager_Pid, Neuron_Number) ->
  gen_statem:cast(gen_Name("neuron", Neuron_Number), {change_parameters, Manager_Pid, Parameters}).
change_weights(Weights, Manager_Pid, Neuron_Number) ->
  gen_statem:cast(gen_Name("neuron", Neuron_Number), {change_weights, Manager_Pid, Weights}).
determine_output(Input_Len, Manager_Pid, Value, Neuron_Number) ->
  gen_statem:cast(gen_Name("neuron", Neuron_Number), {output_path, Manager_Pid, Input_Len, Value}).
stop_neuron(Neuron_Number) -> gen_statem:cast(gen_Name("neuron", Neuron_Number), {stop}).

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
%%  Dt = 0.125,
%%  L = arange(0, 50 + Dt, Dt),
%%  L1 = mapMult([1,2,3], [4,5,6]),
  ParaMap =
    maps:put(dt, 0.125,
      maps:put(simulation_time, 50,
        maps:put(t_rest, 0,
          maps:put(rm, 1,
            maps:put(cm, 10,
              maps:put(tau_ref, 4,
                maps:put(vth, 1,
                  maps:put(v_spike, 0.5,
                    maps:put(i_app, 0, maps:new()))))))))),
  {ok, Pid} = neuron:start_link(1, regular, nothing, ParaMap),
  sys:trace(Pid, true),
  Length = math:ceil(maps:get(simulation_time, ParaMap) / maps:get(dt, ParaMap)),
  I = list_same(1.5, Length + 1),
%%  neuron:change_weights([1, 20, 30], 1),
%%  neuron:new_data(I, 1),
%%  neuron:determine_output(3, 10, 1),
%%  neuron:determine_output(3, 20, 1),
%%  neuron:determine_output(3, 30, 1),
  neuron:stop_neuron(1),
  hey.

%% @doc  Receives: Str - String
%%                          Neuron_Number - The number of the neuron
%%            Returns:  An atom with the appropriate name
gen_Name(Str, Neuron_Number) ->
  list_to_atom(lists:flatten(io_lib:format("~s~B", [Str, Neuron_Number]))).

%% TODO: Create the update weights function
%% @doc  Receives: t - Time difference between presynaptic and postsynaptic spikes
%%                          A_plus, Tau_plus - Time difference is positive i.e negative reinforcement
%%                          A_minus, Tau_minus - Time difference is negative i.e positive reinforcement
%%      Returns:  STDP reinforcement learning curve
%%rl(_t) ->
%%  A_plus = 0.8,
%%  A_minus = 0.3,
%%  Tau_plus = 10,
%%  Tau_minus = 10,
%%  if
%%    _t > 0 -> -A_plus * math:exp(-_t / Tau_plus);
%%    true -> A_minus * math:exp(_t / Tau_minus)
%%  end.


%% @doc  Receives: State - The values of the parameters in shape of record
%%                I_synapse - The current after mult with the weights
%%                Time_List  In order to move on all the values of time
%%                Prev_Vm - The voltage before
%%      Returns:  List of values of lif neuron
lif(I_synapse, Time_List, _, _, Spike_train) when (I_synapse == [] orelse Time_List == []) ->
  [spike_train | lists:reverse(Spike_train)]; % Inorder to send also the spike train
lif(I_synapse, Time_List, State, Prev_Vm, Spike_train) ->
  I = hd(I_synapse),
  Vm_now = if
             hd(Time_List) > State#neuron_state.t_rest ->
               Prev_Vm + ((State#neuron_state.rm * I - Prev_Vm) / State#neuron_state.tau_m + State#neuron_state.i_app) * State#neuron_state.dt;
             true -> 0
           end,
  case Vm_now >= State#neuron_state.vth of
    true -> % Means we have a spike
      Spike = 1,
      Vm_result = Vm_now + State#neuron_state.v_spike,
      T_rest_new = hd(Time_List) + State#neuron_state.tau_ref;
    false -> % Means we don't have a spike
      Spike = 0,
      Vm_result = Vm_now,
      T_rest_new = State#neuron_state.t_rest
  end,
  [Vm_result | lif(tl(I_synapse), tl(Time_List), State#neuron_state{t_rest = T_rest_new}, Vm_result, [Spike | Spike_train])].

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
list_same(_, Finish) when (Finish == 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].


%% @doc  Receives: I - Current for input neuron [1, 0, 0, 1, 0]
%%                          Weights - From output neurons [4, 5, 6]
%%      Returns:  A list of their mult [[4, 0, 0, 4, 0], [5, 0, 0, 5, 0], [6, 0, 0, 6, 0]]
synapses(_, []) ->
  [];
synapses(I, Weights) ->
  I_synapse = [hd(Weights) * X || X <- I],
  [I_synapse | synapses(I, tl(Weights))].


%% @doc  Receives: L1 - List 1 [1, 2, 3]
%%                         Arg2 - List 2 [4, 5, 6] / number 4
%%      Returns:  A list of their mult [4, 10, 18] / mult by number [4, 8, 12]
mapMult(List1, []) ->
  lists:map(fun(X) -> (X) end, List1);
mapMult(List1, Args2) when (is_list(Args2) and is_number(Args2)) ->
  lists:map(fun(X) -> (X * Args2) end, List1);
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
listsToCouple([H1 | T1], [H2 | T2], Acc) ->
  listsToCouple(T1, T2, [[H1 | [H2]] | Acc]).

%% @doc  Receives: List - A List of numbers
%%                          Elem - The element we want to find in the list
%%      Returns:  A list of what comes after Elem
returnFromElem([], _) ->
  notFound;
returnFromElem([H | T], Elem) when Elem == H ->
  T;
returnFromElem([_ | Rest], Elem) ->
  returnFromElem(Rest, Elem).

%% @doc  Receives: List - A List of numbers
%%                          Elem - The element we want to find in the list
%%                          K - Location in list
%%      Returns:  His first location in the list
findElemLocation([], _, _) ->
  notFound;
findElemLocation([H | _], Elem, K) when Elem == H ->
  K;
findElemLocation([_ | Rest], Elem, K) ->
  findElemLocation(Rest, Elem, K + 1).