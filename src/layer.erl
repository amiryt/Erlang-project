%%%-------------------------------------------------------------------
%%% @author amiryt
%%% @copyright (C) 2020, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 19. ספט׳ 2020 12:44
%%%-------------------------------------------------------------------
-module(layer).
-author("amiryt").

%% gen_server callbacks
-export([start/1]).


start(N) ->

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
%%  {ok, P1} = neuron:start_link(1, regular, ParaMap),
%%  {ok, P2} = neuron:start_link(2, regular, ParaMap),
  ets:new(layerEts, [ordered_set, named_table]),
  initiate_layer(N, ParaMap, layerEts).


%% @doc  Receives: N - Number of neurons to be made
%%                ParaMap - The map of the parameters
%%                EtsName - The ets name (if we use "bag", we need the ID!!)
%%                Creates N neurons and sends the information to the manager server
initiate_layer(0, _, _) ->
  io:format("Finished building layer~n");
initiate_layer(N, ParaMap, EtsName) ->
  io:format("Layer(initiate_layer): Neuron ~p created!~n", [N]),
%%  TODO: Check this!!! & put correct weights in the beginning
  Neuron_info = create_neuron(regular, N, ParaMap),
  ets:insert(EtsName, Neuron_info),
  initiate_layer(N - 1, ParaMap, EtsName).


%% @doc  Receives: Number - The number of the neuron
%%                Start_Option - If we start "regular" or from "restore"
%%                ParaMap - The map of the parameters
%%      Returns:  A tuple: {Neuron_number, Neuron_pid, Parameters_map}
create_neuron(Start_Option, Number, ParaMap) ->
%%  TODO: Add here self() (of the layer) to send the neuron
  Pid_Neuron = spawn(fun() -> actions_neuron(Number) end), % This is the Pid of the neuron
%%  sys:trace(Pid, true),
  Pid_Neuron ! {create, {Number, self()}, Start_Option, ParaMap},
  receive
    Info -> Info
  end.
%%  {Number, Pid, ParaMap}.
%%  Length = math:ceil(maps:get(simulation_time, ParaMap) / maps:get(dt, ParaMap)),
%%  I = list_same(1.5, Length + 1),
%%  neuron:new_data(I),
%%  TODO: Add receive option from the neuron

actions_neuron(Neuron_Number) ->
  receive
    {create, {Number, Sender_Pid}, Operation_Mode, ParaMap} when Number == Neuron_Number ->
      {ok, NeuronStatem_Pid} = neuron:start_link(Number, Operation_Mode, ParaMap),
%%      TODO: Understand if we want to save the pif from the statem (Neuron_Pid) or the process in the layer (self())
      Sender_Pid ! {Neuron_Number, NeuronStatem_Pid, ParaMap}
  end,
  actions_neuron(Neuron_Number). % Inorder to stay in the loop of receiving orders
%% Local side
%% Address <=> 'name@<localhost>'
%%startChat(Address) ->
%%  put(remoteNode, Address),%% In order to use it later
%%%%  net_kernel:connect_node(remoteNode),
%%  case whereis(localPid) of
%%    undefined -> spawn(fun() ->
%%      rpc:call(Address, ?MODULE, call, [{start, node()}]),%% Node: Address, Module: This module, Function: call, Args: Message - Activate "call" in remote machine
%%      register(localPid, self()),%% Save the Pid of the local host process
%%      localLoop(Address, 0, 0) end);
%%    _ -> io:format("You already started a chat~n")
%%  end.


%% @doc  Receives: Num - The number we want
%%                Len - Number of times that "Num" would appear
%%      Returns:  A list with the same elements Len times
list_same(_, Finish) when (Finish == 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].