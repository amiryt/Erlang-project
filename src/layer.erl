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
-export([start/0, active_input_layer/1]).
-record(neurons, {input_layer = 5, output_layer = 4}).

start() ->
  Neurons = #neurons{},
  In = element(2, Neurons),
  Out = element(3, Neurons),
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
  ets:new(neuronEts, [ordered_set, named_table]), % For backup the settings of the neuron
  ets:new(weightsEts, [ordered_set, named_table]), % For easy access to the weights
  initiate_layer(1, In, ParaMap, neuronEts), % Input layer - 5 neurons
  initiate_layer(In + 1, In + Out, ParaMap, neuronEts), % Output layer - 4 neurons
%% TODO: Return this
  Weights_List = ["16.0\t26\t36.65\t46\t56", "17\t27\t37\t47\t57.8", "18\t28\t38\t48\t58", "19\t29\t39\t49\t59"],
%%  Weights_List = get_file_contents("weights.txt"),
  backup_weights(In, In + 1, Weights_List, weightsEts), % Save the weights in separate ets to have a backup of them in case we will need
  initiate_weights(In, In + 1, In + Out, weightsEts, neuronEts), % Setting the weights by sending them to the neurons in the output layer
%%  TODO: Delete this
  Length = math:ceil(maps:get(simulation_time, ParaMap) / maps:get(dt, ParaMap)),
  I = list_same(1.5, Length + 1),
  active_input_layer(I).

%% @doc  Receives: I - The information from the picture
%%                Sends the information arrived from the user's picture to the input layer
active_input_layer(I) ->
  hey.
%% --------------------------------------------------------------------------------------
%%                          LAYER CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: N - Number of neurons to be made
%%                StartPoint - The number of neuron we start from
%%                ParaMap - The map of the parameters
%%                EtsName - The ets name (if we use "bag", we need the ID!!)
%%                Creates N neurons and sends the information to the manager server
initiate_layer(Finish, N, _, _) when Finish == N + 1 ->
  io:format("Finished building layer~n");
initiate_layer(StartPoint, N, ParaMap, EtsName) ->
  io:format("Layer(initiate_layer): Neuron ~p created!~n", [StartPoint]),
  Neuron_info = create_neuron(regular, StartPoint, ParaMap),
  ets:insert(EtsName, Neuron_info),
  initiate_layer(StartPoint + 1, N, ParaMap, EtsName).


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

%% @doc  Receives: Neuron_Number - The number of the neuron
%%      This function is response on the connections between each neuron to the system (which are the layers)
actions_neuron(Neuron_Number) ->
  receive
    {create, {Number, Sender_Pid}, Operation_Mode, ParaMap} when Number == Neuron_Number ->
      {ok, NeuronStatem_Pid} = neuron:start_link(Number, Operation_Mode, self(), ParaMap),
%%      TODO: Understand if we want to save the pid from the statem (Neuron_Pid) or the process in the layer (self())
      Sender_Pid ! {Neuron_Number, NeuronStatem_Pid, self(), ParaMap}; % {1, Pid68 (statem - for tracking), Pid71 (neuron pid in the layer), parameters map}
    {weights, Sender_Pid, Weights} ->
      neuron:change_weights(Weights, Neuron_Number);
    {spikes_from_neuron, Spike_train} -> % The current received from the neuron
      Spike_train,
      hey
%%  TODO: Add here state actions of: new_data, sending forward to the appropriate neurons
  end,
  actions_neuron(Neuron_Number). % Inorder to stay in the loop of receiving orders

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS BACKUP FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Weights - A list of weights
%%                WeightsEts - The ets name of weights
%%                Backup all the weights of the neurons in an ets
backup_weights(_, _, [], _) ->
  io:format("Finished backup weights~n");
backup_weights(Input_Len, Output_Neuron, Weights, WeightsEts) ->
  io:format("Layer(backup_weights): Setting output neuron weights backup~n"),
  Weights_List = list_to_numbers(length(string:tokens(hd(Weights), "\t")), string:tokens(hd(Weights), "\t")), % Splits from the tab
  save_weights(1, Input_Len, Output_Neuron, Weights_List, WeightsEts), % We save the weights in order to have a backup of them
  backup_weights(Input_Len, Output_Neuron + 1, tl(Weights), WeightsEts).


%% @doc  Receives: Start - The neuron we work on from input layer
%%                Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Weights_List - A list of weights for the specific output neuron
%%                WeightsEts - The ets name of weights
%%                Save all the weights of the neurons
save_weights(Start, Input_Len, Output_Neuron, [], _) when Start > Input_Len ->
  io:format("Finished saving weights for neuron~p~n", [Output_Neuron]);
save_weights(Start, Input_Len, Output_Neuron, Weights_List, WeightsEts) ->
  io:format("Saving weight ~p between neuron~p to neuron~p~n", [hd(Weights_List), Start, Output_Neuron]),
  ets:insert(WeightsEts, {{Start, Output_Neuron}, hd(Weights_List)}),
  save_weights(Start + 1, Input_Len, Output_Neuron, tl(Weights_List), WeightsEts).

%% --------------------------------------------------------------------------------------
%%                          WEIGHTS CONFIGURATION FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc  Receives: Input_Len - Number of neurons in the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                Finish - The number of the last neuron in the output layer
%%                WeightsEts - The ets name of weights
%%                NeuronEts - The ets name of neurons
%%                Sets all the weights of the neurons
initiate_weights(_, Output_Neuron, Finish, _, _) when Output_Neuron == Finish + 1 ->
  io:format("Finished setting weights in network~n");
initiate_weights(Input_Len, Output_Neuron, Finish, WeightsEts, NeuronEts) ->
  io:format("Layer(initiate_weights): Setting output neuron~p weights~n", [Output_Neuron]),
  Neurons_Numbers = lists:seq(1, Input_Len),
  set_weights(Neurons_Numbers, Output_Neuron, WeightsEts, NeuronEts, []),
  initiate_weights(Input_Len, Output_Neuron + 1, Finish, WeightsEts, NeuronEts).


%% @doc  Receives: Neurons_Numbers - The neurons of the input layer
%%                Output_Neuron - The number of the output neuron we work on
%%                WeightsEts - The ets name of weights
%%                NeuronsEts - The ets name of neurons
%%                Set all the weights of the input neurons with that "Output_Neuron"
set_weights([], Output_Neuron, _, NeuronEts, Weights_List) ->
  Weights = lists:reverse(Weights_List),
  Output_Neuron_Info = hd(ets:lookup(NeuronEts, Output_Neuron)),
  Pid_Output = element(3, Output_Neuron_Info),
  Pid_Output ! {weights, self(), Weights}, % The layer sends request to the neuron to change his weights
  finished;
set_weights(Neurons_Numbers, Output_Neuron, WeightsEts, NeuronEts, Weights_List) ->
  io:format("Setting weight between neuron~p to neuron~p~n", [hd(Neurons_Numbers), Output_Neuron]),
  Weight_info = hd(ets:lookup(WeightsEts, {hd(Neurons_Numbers), Output_Neuron})),
  Weight = element(2, Weight_info),
  set_weights(tl(Neurons_Numbers), Output_Neuron, WeightsEts, NeuronEts, [Weight | Weights_List]).

%% --------------------------------------------------------------------------------------


%% --------------------------------------------------------------------------------------
%%                          SUPPORT FUNCTIONS
%% --------------------------------------------------------------------------------------

%% @doc Receives: FileName - The name of the file we want to read
%%      Returns:  The list of the lines of the file

% Get the contents of a text file into a list of lines.
% Each line has its trailing newline removed.
get_file_contents(Name) ->
  {ok, File} = file:open(Name, [read]),
  Rev = get_all_lines(File, []),
  lists:reverse(Rev).

% Auxiliary function for get_file_contents.
get_all_lines(File, Partial) ->
  case io:get_line(File, "") of
    eof -> file:close(File),
      Partial;
    Line -> {Strip, _} = lists:split(length(Line), Line),
      get_all_lines(File, [Strip | Partial])
  end.


%% @doc  Receives: Num - The number we want
%%                Len - Number of times that "Num" would appear
%%      Returns:  A list with the same elements Len times
list_same(_, Finish) when (Finish == 0) ->
  [];
list_same(Num, Len) ->
  [Num | list_same(Num, Len - 1)].


%% @doc Receives: List - List of strings
%%                         Len - List length
%%      Returns:  A list of floats & integers
list_to_numbers(0, []) ->
  [];
list_to_numbers(Len, [H | T]) ->
  [list_to_number(H) | list_to_numbers(Len - 1, T)].

%% @doc Receives: Str - A list that represent one string
%%      Returns:  A float or integer
list_to_number(Str) ->
  try list_to_float(Str) of
    _ ->
      list_to_float(Str)
  catch
    error:_ ->
      try list_to_integer(Str) of
        _ ->
          list_to_integer(Str)
      catch
        error:Error -> {error, Error}
      end
  end.