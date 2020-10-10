-module(graphics).
-author("KyanSleem").

-include_lib("wx/include/wx.hrl").

-export([init/0, startGraph/0, startGui/0]).


%% intiating the graphs handler and the wxwedgits gui
init() ->
  PidGui = spawn(graphics, startGui, []),
  register(gui, PidGui),

  PidGraph = spawn(graphics, startGraph, []),
  register(graph, PidGraph),
  {PidGui, PidGraph}
.

startGraph() ->

  put(recivedmessages, 0),

  graphHanlder()
.


%% to reieve messages to draw graphs
graphHanlder() ->


  receive


  %% recieveing messages
    {monitor, terminate} ->
      erlang:display("monitor terminating the system"),
      ok;
    {monitor, exit} ->
      ok;%%io:fwrite("recieved exit message I graph  ~n", []);


    {server, draw, Nm, NeuronNumber} ->

      put(recivedmessages, get(recivedmessages) + 1),


      case NeuronNumber of
        1 -> put(neuron1, Nm);
        2 -> put(neuron2, Nm);
        3 -> put(neuron3, Nm);
        4 -> put(neuron4, Nm);
        _ -> nothingtodo
      end,

      case get(recivedmessages) of
        4 -> put(recivedmessages, 0),
          Res = draw(get(neuron1), get(neuron2), get(neuron3), get(neuron4)),
          case Res of%%  is blocking way to draw you need to exit hte window to move
            1 ->
              spawn(server, endTest, [server, 'serverNode@127.0.0.1', 1]);
            _ -> ok
          end;
        _ -> nothingtodo

      end,

      graphHanlder();


    _ -> 1


  end

.


%% to start the gui

startGui() ->
  State = make_window(),
  put(isactive, 0),

  loop(State), %% need to make a spawn function to recieve from the server

  wx:destroy().


%% making the window

make_window() ->
  Server = wx:new(),
  Frame = wxFrame:new(Server, -1, "SNN", [{size, {400, 600}}]),

  Panel = wxPanel:new(Frame),
  wxPanel:setBackgroundStyle(Panel, ?wxBG_STYLE_CUSTOM),
  wxFrame:setBackgroundColour(Frame, {100, 0, 0}),


  MainSizer = wxBoxSizer:new(?wxVERTICAL),
  TextSizer = wxStaticBoxSizer:new(?wxVERTICAL, Panel,
    [{label, "How to use: "}]),
  BitmapSizer = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 1"}]),
  BitmapSizer1 = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 2"}]),
  BitmapSizer2 = wxStaticBoxSizer:new(?wxHORIZONTAL, Panel,
    [{label, "image number 3"}]),


  %% Create static texts
  Texts = [wxStaticText:new(Panel, 1, "info", []),
    wxStaticText:new(Panel, 2, "info",
      [{style, ?wxALIGN_CENTER bor ?wxST_NO_AUTORESIZE}]),
    wxStaticText:new(Panel, 3, "info",
      [{style, ?wxALIGN_RIGHT bor ?wxST_NO_AUTORESIZE}])],


  Image = wxImage:new("image0.jpg", []),
  Bitmap = wxBitmap:new(wxImage:scale(Image,
    round(wxImage:getWidth(Image) * 4),
    round(wxImage:getHeight(Image) * 4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap = wxStaticBitmap:new(Panel, 1, Bitmap),

  Image1 = wxImage:new("image1.jpg", []),
  Bitmap1 = wxBitmap:new(wxImage:scale(Image1,
    round(wxImage:getWidth(Image1) * 4),
    round(wxImage:getHeight(Image1) * 4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap1 = wxStaticBitmap:new(Panel, 2, Bitmap1),


  Image2 = wxImage:new("image2.jpg", []),
  Bitmap2 = wxBitmap:new(wxImage:scale(Image2,
    round(wxImage:getWidth(Image2) * 4),
    round(wxImage:getHeight(Image2) * 4),
    [{quality, ?wxIMAGE_QUALITY_HIGH}])),
  StaticBitmap2 = wxStaticBitmap:new(Panel, 3, Bitmap2),


  %% Add to sizers
  [wxSizer:add(TextSizer, Text, [{flag, ?wxEXPAND bor ?wxALL},
    {border, 10}]) || Text <- Texts],


  wxSizer:add(BitmapSizer, StaticBitmap, []),
  wxSizer:add(BitmapSizer1, StaticBitmap1, []),
  wxSizer:add(BitmapSizer2, StaticBitmap2, []),
  wxSizer:add(MainSizer, TextSizer, [{flag, ?wxEXPAND}]),
  wxSizer:add(MainSizer, BitmapSizer, []),
  wxSizer:add(MainSizer, BitmapSizer1, []),
  wxSizer:add(MainSizer, BitmapSizer2, []),


%% create widgets
%% the order entered here does not control appearance
  T1001 = wxTextCtrl:new(Panel, 1001, [{value, "1"}]), %set default value
  ST2001 = wxStaticText:new(Panel, 2001, "Output Area", []),
  ST2002 = wxStaticText:new(Panel, 2001, "Chose input image", []),


  B100 = wxButton:new(Panel, 100, [{label, "Draw"}]),%% 101 is the id
  B101 = wxButton:new(Panel, 101, [{label, "&Send"}]),%% 101 is the id


  B102 = wxButton:new(Panel, ?wxID_EXIT, [{label, "E&xit"}]),%% ?wxId_EXIT

  OuterSizer = wxBoxSizer:new(?wxHORIZONTAL),

  InputSizer = wxBoxSizer:new(?wxVERTICAL),%%% distance from up of the frame
  ButtonSizer = wxBoxSizer:new(?wxHORIZONTAL),
  ButtonSizerD = wxBoxSizer:new(?wxVERTICAL),


  wxSizer:add(InputSizer, ST2002, []),
  wxSizer:add(InputSizer, 40, 0, []),

  wxSizer:addSpacer(MainSizer, 10),  %spacer
  wxSizer:add(InputSizer, T1001, []),
  wxSizer:addSpacer(MainSizer, 5),  %spacer

  wxSizer:addSpacer(MainSizer, 10),  %spacer
  wxSizer:add(MainSizer, InputSizer, []),
  wxSizer:addSpacer(MainSizer, 5),  %spacer

  wxSizer:add(MainSizer, ST2001, []),
  wxSizer:addSpacer(MainSizer, 10),  %spacer
  wxSizer:add(ButtonSizerD, B100, []),
  wxSizer:add(MainSizer, ButtonSizerD, []),
  wxSizer:add(ButtonSizer, B101, []),
  wxSizer:add(ButtonSizer, B102, []),
  wxSizer:add(MainSizer, ButtonSizer, []),

  wxSizer:addSpacer(OuterSizer, 20), % spacer
  wxSizer:add(OuterSizer, MainSizer, []),


%% Now 'set' OuterSizer into the Panel


  wxPanel:setSizer(Panel, OuterSizer),

  wxFrame:show(Frame),

% create two listeners
  wxFrame:connect(Frame, close_window),
  wxPanel:connect(Panel, command_button_clicked),

%% the return value, which is stored in State
  {Frame, T1001, ST2001}.

loop(State) ->
  {Frame, T1001, ST2001} = State,  % break State back down into its components
  %%io:format("--waiting in the loop--~n", []), % optional, feedback to the shell

  receive

  % a connection get the close_window signal
  % and sends this message to the server
    {monitor, terminate} ->
      erlang:display("monitor terminating the system"),
    wxWindow:destroy(Frame),  %closes the window
      ok;
    {server, finished} ->
      put(isactive, 0),
      wxStaticText:setLabel(ST2001, "you can inter"),

      loop(State);

  %% recieveing mesagews from out server
    {monitor, exit} -> ok;




    #wx{event = #wxClose{}} ->
      %% need to terminate the application
      spawn(server, terminateApp, [server, 'serverNode@127.0.0.1', 1]),
        %closes the window
      loop(State);%% then wait for the monitor termination
        % we exit the loop

    #wx{id = ?wxID_EXIT, event = #wxCommand{type = command_button_clicked}} ->
      spawn(server, terminateApp, [server, 'serverNode@127.0.0.1', 1]),
      %closes the window
      loop(State),

      ok;  % we exit the loop

    #wx{id = 100, event = #wxCommand{type = command_button_clicked}} ->
      wxStaticText:setLabel(ST2001, "DRAWING: at the end press save, then exit!"),
      {ok, PyPID} = python:start([{python_path, "conv.py"}, {python, "python3"}]),
      python:call(PyPID, paint, draw, []),
      wxStaticText:setLabel(ST2001, " choose option number 4, to send the drawed Image"),

      loop(State);

    #wx{id = 101, event = #wxCommand{type = command_button_clicked}} ->

      T1001_val = wxTextCtrl:getValue(T1001),
      case is_valid_list_to_integer(T1001_val) of
        true ->
          case get(isactive) of

            0 ->
              case list_to_integer(T1001_val) of
                1 -> put(isactive, 1),
                  spawn(server, testImage, [server, 'serverNode@127.0.0.1', conv1(0)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");

                2 -> put(isactive, 1),

                  spawn(server, testImage, [server, 'serverNode@127.0.0.1', conv1(1)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");


                3 -> put(isactive, 1),
                  spawn(server, testImage, [server, 'serverNode@127.0.0.1', conv1(2)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");


                4 -> put(isactive, 1),
                  spawn(server, testImage, [server, 'serverNode@127.0.0.1', conv1(3)]),
                  wxStaticText:setLabel(ST2001, "The network in progress please wait");

                _ -> wxStaticText:setLabel(ST2001, "Invalid input, Please chose again")
              end;


            _ -> wxStaticText:setLabel(ST2001, "The network in progress please wait")
          end;
        _ ->
          wxStaticText:setLabel(ST2001, "Only integers are allowed")
      end,


      loop(State);

    _-> ok
  %everything else ends up here
  %%:format("loop default triggered: Got ~n ~p ~n", [Msg])
  %loop(State)

  end.


is_valid_list_to_integer(Input) ->
  try list_to_integer(Input) of
    _An_integer -> true
  catch
    error: _Reason -> false  %Reason is badarg
  end.





conv1(ImageNum) ->

  {ok, PyPID} = python:start([{python_path, "conv.py"}, {python, "python3"}]),
  Result = python:call(PyPID, conv, getImageTraing, [ImageNum]),

  Result

.

draw(Nm1, Nm2, Nm3, Nm4) ->

  {ok, PyPID} = python:start([{python_path, "test.py"}, {python, "python3"}]),
  Result = python:call(PyPID, test, print, [[Nm1, Nm2, Nm3, Nm4]]),
  case Result of
    1 -> 1;
    _ -> 0
  end

.
