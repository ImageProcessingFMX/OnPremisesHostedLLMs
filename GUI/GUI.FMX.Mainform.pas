unit GUI.FMX.Mainform;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ListBox, FMX.Layouts, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, FMX.Memo.Types, FMX.ScrollBox, FMX.Memo ,
  ///
  ///  Your existing units
  ///
  Unit_AIModel.Communication,
  Unit_AIModel.GetInternalToken,
  Unit_AIModel.Helper,
  Unit_AIModel.TAIModelConfig,
  Unit_AIModel.Embeddings,
  Unit_AIModel.Probing;

type
  /// <summary>
  /// Test Application Date 27.04.2026
  /// </summary>
  TFormMain = class(TForm)
    Layout1: TLayout;
    ComboBoxModel: TComboBox;
    Panel1: TPanel;
    LabelStatusbar: TLabel;
    Edit_Username: TEdit;
    EditWinPassword: TEdit;
    ButtonTestConnection: TButton;
    ButtonLoadConfig: TButton;
    CheckBoxdebug: TCheckBox;
    Button_FetchModels: TButton;
    OpenDialog: TOpenDialog;
    Label_Username: TLabel;
    Label_Winpassword: TLabel;
    Layout2: TLayout;
    ButtonSendQuery: TButton;
    Button_EmbeddingsT1: TButton;
    ButtonClear: TButton;
    LabelModelName: TLabel;
    Layout3: TLayout;
    MemoResponse: TMemo;
    MemoQuestion: TMemo;
    EditAPIKey: TEdit;
    ButtonGetAPIKey: TButton;
    GroupBoxAuthenticationMode: TGroupBox;
    RadioButton_Winlogin: TRadioButton;
    RadioButton_URL: TRadioButton;
    RadioButton_CopyAndPaste: TRadioButton;
    LabelAPIKey: TLabel;
    EditURL: TEdit;
    LabelURL: TLabel;
    Button_EmbeddingsT2: TButton;
    Button_EmbeddingsT3: TButton;
    Button_EmbeddingsT4: TButton;
    Button_EmbeddingsT5: TButton;
    Button_EmbeddingsT6: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ButtonTestConnectionClick(Sender: TObject);
    procedure Edit_UsernameChange(Sender: TObject);
    procedure EditWinPasswordChange(Sender: TObject);
    procedure ButtonSendQueryClick(Sender: TObject);
    procedure Button_FetchModelsClick(Sender: TObject);
    procedure ButtonLoadConfigClick(Sender: TObject);
    procedure Button_EmbeddingsT1Click(Sender: TObject);
    procedure ButtonGetAPIKeyClick(Sender: TObject);
    procedure Button_EmbeddingsT2Click(Sender: TObject);
    procedure Button_EmbeddingsT3Click(Sender: TObject);
    procedure Button_EmbeddingsT4Click(Sender: TObject);
    procedure Button_EmbeddingsT5Click(Sender: TObject);
    procedure Button_EmbeddingsT6Click(Sender: TObject);
    procedure ComboBoxModelChange(Sender: TObject);
  private
    { Private declarations }

    FAIModelConfig: TAIModelConfig;

    FAuthHeader: string;

    FEnableDebug: Boolean;

    FWinUser, FWinPass: String;

    FModel: String;

    procedure UpdateStatus(const Msg: string);
    procedure InitializeConfig;
    procedure LoadConfiguration(ConfigFilename: String);
    procedure EnableControls(Enable: Boolean);
    procedure BuildAuthHeader(Sender: TObject);

  public
    { Public declarations }
  end;

var
  FormMain: TFormMain;

implementation

{$R *.fmx}

procedure TFormMain.BuildAuthHeader(Sender: TObject);
var
  Selected: integer;
begin
  if RadioButton_Winlogin.IsChecked then
    Selected := 1 // win login
  else if RadioButton_URL.IsChecked then
    Selected := 2 // URL
  else if RadioButton_CopyAndPaste.IsChecked then
    Selected := 3
  else
    Selected := 3;

  case Selected of
    1:
      begin
        FAuthHeader := 'Bearer ' + GetPermanentTokenViaBasic
          (FAIModelConfig.BaseURL + FAIModelConfig.AuthTokenEndpoint, FWinUser,
          FWinPass, FEnableDebug);
      end;
    2:
      begin
        FAuthHeader := 'Bearer ' + GetCompanyInternalToken;
      end;
    3:
      begin
        FAuthHeader := 'Bearer ' + EditAPIKey.text.trim;
      end

  else
  end;

end;

procedure TFormMain.ButtonSendQueryClick(Sender: TObject);
var
  Question, Answer: string;
begin
  if trim(MemoQuestion.text) = '' then
  begin
    ShowMessage('Please enter a question first');
    MemoQuestion.SetFocus;
    Exit;
  end;

  try
    EnableControls(False);
    UpdateStatus('Sending query...');
    // ProgressBar.Style := pbstMarquee;
    MemoResponse.Lines.Clear;

    BuildAuthHeader(nil);

    // Update model from combobox
    FAIModelConfig.Model := ComboBoxModel.text;

    Question := MemoQuestion.text;
    FEnableDebug := CheckBoxdebug.IsChecked;

    // Use your existing PostChatCompletions function [4]
    Answer := PostChatCompletions(FAuthHeader, Question, FEnableDebug,
      FAIModelConfig);

    MemoResponse.text := Answer;
    UpdateStatus('Query completed successfully');

  except
    on E: Exception do
    begin
      ShowMessage('Error: ' + E.ClassName + ' - ' + E.Message);
      UpdateStatus('Query failed: ' + E.Message);
    end;
  end;

  // ProgressBar.Style := pbstNormal;
  EnableControls(True);
end;

procedure TFormMain.ButtonTestConnectionClick(Sender: TObject);
var
  Info: string;
  Success: Boolean;
begin
  try
    EnableControls(False);
    UpdateStatus('Testing connection...');
    // ProgressBar.Style := pbstMarquee;

    BuildAuthHeader(nil);

    // Use your existing probing functionality [7]
    Success := ProbeModelAccess(ComboBoxModel.text, FAIModelConfig, Info,
      FAuthHeader);

    if Success then
    begin
      ShowMessage('Connection successful!' + sLineBreak + Info);
      UpdateStatus('Connected - Ready to send queries');
    end
    else
    begin
      ShowMessage('Connection failed: ' + sLineBreak + Info);
      UpdateStatus('Connection failed');
    end;

  finally
    // ProgressBar.Style := pbstNormal;
    EnableControls(True);
  end;
end;

procedure TFormMain.Button_EmbeddingsT1Click(Sender: TObject);
var
  Inputs: TArray<string>;
  Results: TArray<TEmbeddingResult>;
  i: integer;
begin
  if trim(MemoQuestion.text) = '' then
  begin
    ShowMessage('Enter text to embed');
    Exit;
  end;

  try
    UpdateStatus('Computing embeddings... SimpleEmbeddingExample  ');

    // Prepare input texts
    SetLength(Inputs, 3);
    Inputs[0] := 'The quick brown fox jumps over the lazy dog';
    Inputs[1] := 'Machine learning is a subset of artificial intelligence';
    Inputs[2] := 'Delphi is a powerful programming language';

    Results := GetEmbeddings(FAuthHeader, Inputs, FModel, FAIModelConfig,
      CheckBoxdebug.IsChecked);

    MemoResponse.Lines.Add(Format('Embedding dimension: %d',
      [Length(Results[0].Embedding)]));


    // MemoResponse.Lines.Add(
    // Format('First 10 values: %s', [
    // string.Join(', ',
    // TArray<string>.Create(
    // Results[0].Embedding[0].ToString,
    // Results[0].Embedding[1].ToString
    // // ... add more
    // ))
    // ])
    // );

    // Display results
    for i := 0 to High(Results) do
    begin
      MemoResponse.Lines.Add('Text #' + Results[i].Index.ToString + ': ' +
        Inputs[i]);
      MemoResponse.Lines.Add('Embedding dimension: ' +
        Length(Results[i].Embedding).ToString);
      MemoResponse.Lines.Add('First 5 values: ');
      if Length(Results[i].Embedding) >= 5 then
      begin
        MemoResponse.Lines.Add('  [');
        MemoResponse.Lines.Add(Results[i].Embedding[0].ToString + ', ');
        MemoResponse.Lines.Add(Results[i].Embedding[1].ToString + ', ');
        MemoResponse.Lines.Add(Results[i].Embedding[2].ToString + ', ');
        MemoResponse.Lines.Add(Results[i].Embedding[3].ToString + ', ');
        MemoResponse.Lines.Add(Results[i].Embedding[4].ToString + ', ');
        MemoResponse.Lines.Add(']');
      end;
      MemoResponse.Lines.Add(' ');
    end;

    UpdateStatus('Embeddings computed using ' + FModel);
  except
    on E: Exception do
      ShowMessage('Error: ' + E.Message);
  end;
end;

procedure TFormMain.Button_EmbeddingsT2Click(Sender: TObject);
Var
  LargeDataset: TArray<string>;
  Results: TArray<TEmbeddingResult>;
  i: integer;
begin

  UpdateStatus('Computing embeddings... BatchProcessingExample  ');

  // Create a large dataset (250 items)
  SetLength(LargeDataset, 250);
  for i := 0 to High(LargeDataset) do
    LargeDataset[i] := Format('Document number %d with some content', [i + 1]);

  MemoResponse.Lines.Add('Processing ' + Length(LargeDataset).ToString +
    ' documents in batches...');

  // Process in batches of 100 with progress reporting
  Results := GetEmbeddingsBatch(FAuthHeader, LargeDataset, FModel,
    FAIModelConfig, 100, // Batch size
    procedure(Current, Total: integer)
    begin
      MemoResponse.Lines.Add(Format('Progress: Batch %d/%d completed',
        [Current, Total]));
    end);

  MemoResponse.Lines.Add('Total embeddings received: ' + Length(Results)
    .ToString);

  UpdateStatus('Embeddings computed using ' + FModel);

end;

procedure TFormMain.Button_EmbeddingsT3Click(Sender: TObject);
var
  Text1, Text2, Text3: string;
  Score: Double;
begin

  UpdateStatus('Computing embeddings... CompareTextsExample  ');

  Text1 := 'I love programming in Delphi';
  Text2 := 'Delphi is great for software development';
  Text3 := 'The weather is nice today';

  // Compare similar texts
  Score := CompareTextsSemantically(FAuthHeader, Text1, Text2, FModel,
    FAIModelConfig, False);
  MemoResponse.Lines.Add(Format('Similarity between Text1 and Text2: %.4f',
    [Score]));

  // Compare dissimilar texts
  Score := CompareTextsSemantically(FAuthHeader, Text1, Text3,
    'sfr-embedding-mistral', FAIModelConfig, False);
  MemoResponse.Lines.Add(Format('Similarity between Text1 and Text3: %.4f',
    [Score]));

  UpdateStatus('Embeddings computed');
end;

procedure TFormMain.Button_EmbeddingsT4Click(Sender: TObject);
var
  Query: string;
  Results: TArray<TEmbeddingResult>;
  Documents: TArray<string>;
  QueryEmbedding: TEmbeddingVector;
  DocEmbeddings: TArray<TEmbeddingVector>;
  TopMatches: TArray<TSimilarityMatch>;
  i: integer;
begin
  UpdateStatus('Computing embeddings... SimilaritySearchExample ');

  // Sample documents
  SetLength(Documents, 5);
  Documents[0] := 'Paris is the capital of France';
  Documents[1] := 'The Eiffel Tower is in Paris';
  Documents[2] := 'Python is a programming language';
  Documents[3] := 'Machine learning uses neural networks';
  Documents[4] := 'France is a country in Europe';

  // Search query
  Query := 'Tell me about Paris';

  // Get embeddings for all documents + query
  SetLength(Documents, Length(Documents) + 1);
  Documents[High(Documents)] := Query;

  Results := GetEmbeddings(FAuthHeader, Documents, FModel,
    FAIModelConfig, False);

  // Separate query embedding from document embeddings
  QueryEmbedding := Results[High(Results)].Embedding;

  SetLength(DocEmbeddings, Length(Results) - 1);
  for i := 0 to High(DocEmbeddings) do
    DocEmbeddings[i] := Results[i].Embedding;

  // Find top 3 most similar documents
  TopMatches := GetTopNSimilar(QueryEmbedding, DocEmbeddings, 3);

  MemoResponse.Lines.Add('Query: "' + Query + '"');
  MemoResponse.Lines.Add('Top 3 most similar documents:');
  MemoResponse.Lines.Add('');

  for i := 0 to High(TopMatches) do
  begin
    MemoResponse.Lines.Add(Format('#%d - Similarity: %.4f',
      [i + 1, TopMatches[i].Score]));
    MemoResponse.Lines.Add('Document: "' + Documents[TopMatches[i].
      Index] + '"');
    MemoResponse.Lines.Add('');
  end;

  UpdateStatus('Embeddings computed');
end;

procedure TFormMain.EditWinPasswordChange(Sender: TObject);
begin
  FWinPass := EditWinPassword.text;
end;

procedure TFormMain.Edit_UsernameChange(Sender: TObject);
begin
  FWinUser := Edit_Username.text;
end;

procedure TFormMain.EnableControls(Enable: Boolean);
begin
  ButtonSendQuery.Enabled := Enable;
  ButtonTestConnection.Enabled := Enable;
  ButtonLoadConfig.Enabled := Enable;
  ComboBoxModel.Enabled := Enable;
  MemoQuestion.Enabled := Enable;
end;

procedure TFormMain.InitializeConfig;
begin
  // Set default parameters from your console app [2]
  FAIModelConfig.BaseURL := HostURL;
  FAIModelConfig.ChatCompletionsPath := '/chat/completions';
  FAIModelConfig.CompletionsPath := '/completions';
  FAIModelConfig.Model := 'gpt-5.3-chat';
  FAIModelConfig.MaxTokens := 2048;
  FAIModelConfig.TimeoutMS := 120000;
  FAIModelConfig.Temperature := 0.7;

  /// Update  GUT

  EditURL.text := FAIModelConfig.BaseURL;

end;

procedure TFormMain.LoadConfiguration(ConfigFilename: String);
var
  ModelIndex: integer;
begin
  try
    UpdateStatus('Loading configuration...');

    if FileExists(ConfigFilename) then
    begin
      // Use your existing TAIModelConfig loading mechanism [8]
      if LoadAIModelConfig(ConfigFilename, FAIModelConfig) then
      begin
        UpdateStatus('Configuration loaded successfully');

        ModelIndex := ComboBoxModel.Items.IndexOf(FAIModelConfig.Model);

        /// Update  GUT

        EditURL.text := FAIModelConfig.BaseURL;

        if ModelIndex >= 0 then
        begin

          ComboBoxModel.ItemIndex := ModelIndex;
        end;

      end
      else
        UpdateStatus('Using default configuration');
    end
    else
    begin
      UpdateStatus('Config file not found - using defaults');
    end;
  except
    on E: Exception do
    begin
      ShowMessage('Error loading configuration: ' + E.Message);
      UpdateStatus('Error loading config');
    end;
  end;
end;


// GetPermanentTokenViaBasic(WinUser, WinPass, EnableDebug);

procedure TFormMain.Button_FetchModelsClick(Sender: TObject);
var
  Models: TArray<string>;
  Info: string;
begin
  try
    UpdateStatus('Fetching models...');
    ComboBoxModel.Clear;

    // Ensure you already have FAuthHeader (Bearer ...) like your GUI does before sending queries [13]
    if (FAuthHeader.trim = '') or SameText(FAuthHeader.trim, 'Bearer') or
      SameText(FAuthHeader.trim, 'Bearer ') then
      raise Exception.Create('No auth header. Please authenticate first.');

    // Calls your existing probing logic that hits the models endpoint and parses data[].id [7]
    if not FetchModelsList(FAuthHeader, FAIModelConfig, Models, Info,
      FEnableDebug) then
      raise Exception.Create('FetchModels failed: ' + Info);

    ComboBoxModel.BeginUpdate;
    try
      ComboBoxModel.Items.AddStrings(Models);
      if ComboBoxModel.Items.Count > 0 then
        ComboBoxModel.ItemIndex := 0;
    finally
      ComboBoxModel.EndUpdate;
    end;

    UpdateStatus(Format('Models loaded: %d', [Length(Models)]));
  except
    on E: Exception do
    begin
      UpdateStatus('Error: ' + E.Message);
      ShowMessage(E.Message);
    end;
  end;
end;

procedure TFormMain.ComboBoxModelChange(Sender: TObject);
begin
  FModel := ComboBoxModel.Items[ComboBoxModel.ItemIndex];

  UpdateStatus('Select a new model : ' + FModel);
end;

procedure TFormMain.ButtonGetAPIKeyClick(Sender: TObject);
begin
  EditAPIKey.text := GetCompanyInternalToken;
end;

procedure TFormMain.ButtonLoadConfigClick(Sender: TObject);
begin
  if OpenDialog.Execute then
  begin
    LoadConfiguration(OpenDialog.FileName)
  end;
end;

procedure TFormMain.Button_EmbeddingsT5Click(Sender: TObject);
var
  Cache: TDictionary<string, TEmbeddingVector>;
  Inputs: TArray<string>;
  Results: TArray<TEmbeddingResult>;
  i: integer;
begin
  UpdateStatus('Computing embeddings... CachedEmbeddingsExample  ');

  Cache := TDictionary<string, TEmbeddingVector>.Create;
  try
    // First call - all cache misses
    SetLength(Inputs, 3);
    Inputs[0] := 'Text A';
    Inputs[1] := 'Text B';
    Inputs[2] := 'Text C';

    MemoResponse.Lines.Add('First call:');
    Results := GetEmbeddingsWithCache(FAuthHeader, Inputs, FModel,
      FAIModelConfig, Cache, True);
    MemoResponse.Lines.Add('Cache size: ' + Cache.Count.ToString);
    MemoResponse.Lines.Add('');

    // Second call - some cache hits
    SetLength(Inputs, 4);
    Inputs[0] := 'Text A'; // Cache hit
    Inputs[1] := 'Text D'; // Cache miss
    Inputs[2] := 'Text B'; // Cache hit
    Inputs[3] := 'Text E'; // Cache miss

    MemoResponse.Lines.Add('Second call:');
    Results := GetEmbeddingsWithCache(FAuthHeader, Inputs,
      FModel, FAIModelConfig, Cache, false);
    MemoResponse.Lines.Add('Cache size: '+  Cache.Count.ToString);
    MemoResponse.Lines.Add(' ');

    UpdateStatus('Computing embeddings ' + FModel);

  finally
    Cache.Free;
  end;

end;

procedure TFormMain.Button_EmbeddingsT6Click(Sender: TObject);
var
  LargeText: string;
  Results: TArray<TEmbeddingResult>;
  i: integer;

  ChunkVectors: TArray<TEmbeddingVector>; // array of vectors (one per chunk)
  AvgVector: TEmbeddingVector; // the averaged embedding vector
begin
  UpdateStatus('Computing embeddings... ChunkedTextExample');

  LargeText := '';
  for i := 1 to 100 do
    LargeText := LargeText + Format('This is sentence number %d. ', [i]);

  MemoResponse.Lines.Add('Original text length: ' + LargeText.Length.ToString +
    ' characters');

  Results := GetChunkedEmbeddings(FAuthHeader, LargeText, 500, FModel,
    FAIModelConfig, 50);

  MemoResponse.Lines.Add('Number of chunks: ' + Length(Results).ToString);

  // Collect vectors
  SetLength(ChunkVectors, Length(Results));
  for i := 0 to High(Results) do
    ChunkVectors[i] := Results[i].Embedding;
  // Embedding is TEmbeddingVector [1]

  // Average them
  AvgVector := AverageEmbeddings(ChunkVectors);
  // expects TArray<TEmbeddingVector> [1]

  MemoResponse.Lines.Add('Average embedding dimension: ' + Length(AvgVector)
    .ToString);

  UpdateStatus('Embeddings computed  using ' + FModel);
end;

procedure TFormMain.ButtonClearClick(Sender: TObject);
begin
  MemoQuestion.Lines.Clear;
  MemoResponse.Lines.Clear;
  MemoQuestion.SetFocus;
  UpdateStatus('Ready');
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  idx: integer;
begin
  // Initialize your AI Model Config
  // FAIModelConfig := TAIModelConfig.Create;

  InitializeConfig;

  ComboBoxModel.BeginUpdate;
  try
    ComboBoxModel.Items.Clear;
    // Set default values based on your console app [2]
    ComboBoxModel.Items.Add('gpt-5.1-chat');
    ComboBoxModel.Items.Add('gpt-5.3-chat');
    ComboBoxModel.Items.Add('gpt-4.1-chat');
    ComboBoxModel.Items.Add('gpt-4o');
    ComboBoxModel.ItemIndex := 0;

    idx := ComboBoxModel.Items.IndexOf(FAIModelConfig.Model);

    if idx >= 0 then
      ComboBoxModel.ItemIndex := idx
    else if ComboBoxModel.Items.Count > 0 then
      ComboBoxModel.ItemIndex := 0

  finally
    ComboBoxModel.EndUpdate;
  end;

  FEnableDebug := False;

  UpdateStatus('Ready !   ( Version 02.05.2026 ) ');
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  // FAIModelConfig.Free;
end;

procedure TFormMain.UpdateStatus(const Msg: string);
begin
  LabelStatusbar.text := Msg;
  Application.ProcessMessages;
end;

end.
