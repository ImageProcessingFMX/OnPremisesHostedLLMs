unit Unit_AIModel.Embeddings;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Net.URLClient, System.Net.HttpClient, System.NetEncoding,  math,

  ///
  ///   My framework :-)
  ///

  Unit_AIModel.Helper,
  Unit_AIModel.TAIModelConfig;

type
  /// Represents a single embedding vector (array of floats)
  TEmbeddingVector = TArray<Double>;


  /// Result from the /embeddings endpoint
type
  TEmbeddingResult = record
    Index: Integer;
    Input: string;              // add this
    Embedding: TEmbeddingVector;
  end;



type
  // Similar to LangChain's "Document" carrying both content and vector
  TTextEmbedding = record
    Text: string;
    Embedding: TEmbeddingVector;
  end;


/// <summary>
/// Similarity match record for search results
/// </summary>
type
  TSimilarityMatch = record
    Index: Integer;
    Score: Double;
  end;

/// <summary>
/// Find the most similar embedding to a query from a list of candidates
/// Returns the index of the most similar embedding
/// </summary>
function FindMostSimilar(
  const QueryEmbedding: TEmbeddingVector;
  const CandidateEmbeddings: TArray<TEmbeddingVector>;
  out SimilarityScore: Double
): Integer;



/// <summary>
/// Calls the /embeddings endpoint (OpenAI-compatible) [1]
/// Returns array of embedding vectors, one per input text.
/// </summary>
function GetEmbeddings(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;      // e.g. 'sfr-embedding-mistral'
  const Config: TAIModelConfig;
  const EnableDebug: Boolean = False
): TArray<TEmbeddingResult>;


/// <summary>
/// Calculate cosine similarity between two embedding vectors
/// Returns value between -1 and 1 (1 = identical, 0 = orthogonal, -1 = opposite)
/// </summary>

function CosineSimilarity(const Vec1, Vec2: TEmbeddingVector): Double;



/// <summary>
/// Calculate Euclidean distance between two embedding vectors
/// Lower values indicate more similarity
/// </summary>
function EuclideanDistance(const Vec1, Vec2: TEmbeddingVector): Double;


/// <summary>
/// Calculate the magnitude (length) of a vector
/// </summary>
function VectorMagnitude(const Vec: TEmbeddingVector): Double;

/// <summary>
/// Normalize an embedding vector to unit length
/// Useful for faster cosine similarity calculations
/// </summary>
function NormalizeVector(const Vec: TEmbeddingVector): TEmbeddingVector;


/// <summary>
/// Calculate dot product of two embedding vectors
/// </summary>
function DotProduct(const Vec1, Vec2: TEmbeddingVector): Double;


/// <summary>
/// Calculate mean/average of multiple embedding vectors
/// Useful for document averaging
/// </summary>
function AverageEmbeddings(const Embeddings: TArray<TEmbeddingVector>): TEmbeddingVector;


/// <summary>
/// Get top N most similar embeddings with their indices and scores
/// Uses cosine similarity for comparison
/// </summary>
function GetTopNSimilar(
  const QueryEmbedding: TEmbeddingVector;
  const CandidateEmbeddings: TArray<TEmbeddingVector>;
  const TopN: Integer
): TArray<TSimilarityMatch>;



/// <summary>
/// Get embeddings with caching to avoid repeated API calls
/// Cache key is the input text
/// </summary>
function GetEmbeddingsWithCache(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;
  const Config: TAIModelConfig;
  const Cache: TDictionary<string, TEmbeddingVector>;
  const EnableDebug: Boolean = False
): TArray<TEmbeddingResult>;


/// <summary>
/// Split large text into chunks and get embeddings for each
/// Useful when text exceeds model's token limit
/// </summary>
function GetChunkedEmbeddings(
  const AuthHeader: string;
  const LargeText: string;
  const ChunkSize: Integer;
  const ModelName: string;
  const Config: TAIModelConfig;
  const OverlapSize: Integer = 0
): TArray<TEmbeddingResult>;


/// <summary>
/// Batch process multiple texts with progress reporting
/// Useful for large datasets
/// </summary>
function GetEmbeddingsBatch(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;
  const Config: TAIModelConfig;
  const BatchSize: Integer = 100;
  const OnProgress: TProc<Integer, Integer> = nil
): TArray<TEmbeddingResult>;

/// <summary>
/// Compare two texts semantically by their embeddings
/// Returns similarity score between -1 and 1 (cosine similarity)
/// </summary>
function CompareTextsSemantically(
  const AuthHeader: string;
  const Text1, Text2: string;
  const ModelName: string;
  const Config: TAIModelConfig;
  const EnableDebug: Boolean = False
): Double;


implementation


function CompareTextsSemantically(
  const AuthHeader: string;
  const Text1, Text2: string;
  const ModelName: string;
  const Config: TAIModelConfig;
  const EnableDebug: Boolean = False
): Double;
var
  Inputs: TArray<string>;
  Results: TArray<TEmbeddingResult>;
begin
  SetLength(Inputs, 2);
  Inputs[0] := Text1;
  Inputs[1] := Text2;

  Results := GetEmbeddings(AuthHeader, Inputs, ModelName, Config, EnableDebug);

  if Length(Results) <> 2 then
    raise Exception.Create('Failed to get embeddings for both texts');

  Result := CosineSimilarity(Results[0].Embedding, Results[1].Embedding);
end;



function CosineSimilarity(const Vec1, Vec2: TEmbeddingVector): Double;
var
  DotProd, Mag1, Mag2: Double;
  i: Integer;
begin
  if Length(Vec1) <> Length(Vec2) then
    raise Exception.Create('Vectors must have the same length');

  DotProd := 0.0;
  Mag1 := 0.0;
  Mag2 := 0.0;

  for i := 0 to High(Vec1) do
  begin
    DotProd := DotProd + (Vec1[i] * Vec2[i]);
    Mag1 := Mag1 + (Vec1[i] * Vec1[i]);
    Mag2 := Mag2 + (Vec2[i] * Vec2[i]);
  end;

  Mag1 := Sqrt(Mag1);
  Mag2 := Sqrt(Mag2);

  if (Mag1 = 0.0) or (Mag2 = 0.0) then
    Result := 0.0
  else
    Result := DotProd / (Mag1 * Mag2);
end;

/// <summary>
/// Calculate Euclidean distance between two embedding vectors
/// Lower values indicate more similarity
/// </summary>
function EuclideanDistance(const Vec1, Vec2: TEmbeddingVector): Double;
var
  Sum: Double;
  i: Integer;
  Diff: Double;
begin
  if Length(Vec1) <> Length(Vec2) then
    raise Exception.Create('Vectors must have the same length');

  Sum := 0.0;
  for i := 0 to High(Vec1) do
  begin
    Diff := Vec1[i] - Vec2[i];
    Sum := Sum + (Diff * Diff);
  end;

  Result := Sqrt(Sum);
end;

/// <summary>
/// Calculate dot product of two embedding vectors
/// </summary>
function DotProduct(const Vec1, Vec2: TEmbeddingVector): Double;
var
  i: Integer;
begin
  if Length(Vec1) <> Length(Vec2) then
    raise Exception.Create('Vectors must have the same length');

  Result := 0.0;
  for i := 0 to High(Vec1) do
    Result := Result + (Vec1[i] * Vec2[i]);
end;


function VectorMagnitude(const Vec: TEmbeddingVector): Double;
var
  Sum: Double;
  i: Integer;
begin
  Sum := 0.0;
  for i := 0 to High(Vec) do
    Sum := Sum + (Vec[i] * Vec[i]);
  Result := Sqrt(Sum);
end;

/// <summary>
/// Normalize an embedding vector to unit length
/// Useful for faster cosine similarity calculations
/// </summary>
function NormalizeVector(const Vec: TEmbeddingVector): TEmbeddingVector;
var
  Mag: Double;
  i: Integer;
begin
  SetLength(Result, Length(Vec));
  Mag := VectorMagnitude(Vec);

  if Mag = 0.0 then
  begin
    // Return zero vector if magnitude is zero
    for i := 0 to High(Vec) do
      Result[i] := 0.0;
  end
  else
  begin
    for i := 0 to High(Vec) do
      Result[i] := Vec[i] / Mag;
  end;
end;

/// <summary>
/// Add two vectors element-wise
/// </summary>
function VectorAdd(const Vec1, Vec2: TEmbeddingVector): TEmbeddingVector;
var
  i: Integer;
begin
  if Length(Vec1) <> Length(Vec2) then
    raise Exception.Create('Vectors must have the same length');

  SetLength(Result, Length(Vec1));
  for i := 0 to High(Vec1) do
    Result[i] := Vec1[i] + Vec2[i];
end;

/// <summary>
/// Calculate mean/average of multiple embedding vectors
/// Useful for document averaging
/// </summary>
function AverageEmbeddings(const Embeddings: TArray<TEmbeddingVector>): TEmbeddingVector;
var
  i, j, VecLen, NumVecs: Integer;
  Sum: Double;
begin
  if Length(Embeddings) = 0 then
    raise Exception.Create('Cannot average empty array of embeddings');

  NumVecs := Length(Embeddings);
  VecLen := Length(Embeddings[0]);

  // Verify all vectors have the same length
  for i := 1 to High(Embeddings) do
  begin
    if Length(Embeddings[i]) <> VecLen then
      raise Exception.Create('All embedding vectors must have the same length');
  end;

  SetLength(Result, VecLen);

  for j := 0 to VecLen - 1 do
  begin
    Sum := 0.0;
    for i := 0 to NumVecs - 1 do
      Sum := Sum + Embeddings[i][j];
    Result[j] := Sum / NumVecs;
  end;
end;




function FindMostSimilar(
  const QueryEmbedding: TEmbeddingVector;
  const CandidateEmbeddings: TArray<TEmbeddingVector>;
  out SimilarityScore: Double
): Integer;
var
  i: Integer;
  Similarity: Double;
  BestScore: Double;
  BestIndex: Integer;
begin
  if Length(CandidateEmbeddings) = 0 then
    raise Exception.Create('Candidate embeddings array is empty');

  BestScore := -2.0; // Lower than minimum possible cosine similarity
  BestIndex := -1;

  for i := 0 to High(CandidateEmbeddings) do
  begin
    Similarity := CosineSimilarity(QueryEmbedding, CandidateEmbeddings[i]);
    if Similarity > BestScore then
    begin
      BestScore := Similarity;
      BestIndex := i;
    end;
  end;

  SimilarityScore := BestScore;
  Result := BestIndex;
end;


function GetTopNSimilar(
  const QueryEmbedding: TEmbeddingVector;
  const CandidateEmbeddings: TArray<TEmbeddingVector>;
  const TopN: Integer
): TArray<TSimilarityMatch>;
var
  i, j, NumResults: Integer;
  Similarity: Double;
  AllMatches: TArray<TSimilarityMatch>;
  TempMatch: TSimilarityMatch;
begin
  if Length(CandidateEmbeddings) = 0 then
    raise Exception.Create('Candidate embeddings array is empty');

  if TopN <= 0 then
    raise Exception.Create('TopN must be greater than 0');

  // Calculate all similarities
  SetLength(AllMatches, Length(CandidateEmbeddings));
  for i := 0 to High(CandidateEmbeddings) do
  begin
    AllMatches[i].Index := i;
    AllMatches[i].Score := CosineSimilarity(QueryEmbedding, CandidateEmbeddings[i]);
  end;

  // Simple bubble sort to get top N (good enough for most use cases)
  // For better performance with large datasets, consider quicksort
  for i := 0 to High(AllMatches) - 1 do
  begin
    for j := i + 1 to High(AllMatches) do
    begin
      if AllMatches[j].Score > AllMatches[i].Score then
      begin
        TempMatch := AllMatches[i];
        AllMatches[i] := AllMatches[j];
        AllMatches[j] := TempMatch;
      end;
    end;
  end;

  // Return top N results
  NumResults := Min(TopN, Length(AllMatches));
  SetLength(Result, NumResults);
  for i := 0 to NumResults - 1 do
    Result[i] := AllMatches[i];
end;


function GetEmbeddingsWithCache(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;
  const Config: TAIModelConfig;
  const Cache: TDictionary<string, TEmbeddingVector>;
  const EnableDebug: Boolean = False
): TArray<TEmbeddingResult>;
var
  i, CachedCount, UncachedCount: Integer;
  UncachedInputs: TArray<string>;
  UncachedIndices: TArray<Integer>;
  ApiResults: TArray<TEmbeddingResult>;
  InputText: string;
begin
  SetLength(Result, Length(Inputs));
  SetLength(UncachedInputs, Length(Inputs));
  SetLength(UncachedIndices, Length(Inputs));

  CachedCount := 0;
  UncachedCount := 0;

  // Check cache for each input
  for i := 0 to High(Inputs) do
  begin
    InputText := Inputs[i];

    if Cache.ContainsKey(InputText) then
    begin
      // Use cached embedding
      Result[i].Input := InputText;
      Result[i].Embedding := Cache[InputText];
      Inc(CachedCount);

      if EnableDebug then
        Writeln('Cache HIT for input #', i);
    end
    else
    begin
      // Mark for API call
      UncachedInputs[UncachedCount] := InputText;
      UncachedIndices[UncachedCount] := i;
      Inc(UncachedCount);

      if EnableDebug and Isconsole  then
        Writeln('Cache MISS for input #', i);
    end;
  end;

  if EnableDebug  and Isconsole then
    Writeln('Cache stats: ', CachedCount, ' hits, ', UncachedCount, ' misses');

  // Make API call for uncached inputs
  if UncachedCount > 0 then
  begin
    SetLength(UncachedInputs, UncachedCount);
    SetLength(UncachedIndices, UncachedCount);

    ApiResults := GetEmbeddings(AuthHeader, UncachedInputs, ModelName, Config, EnableDebug);

    // Store results in cache and result array
    for i := 0 to High(ApiResults) do
    begin
      InputText := ApiResults[i].Input;
      Cache.AddOrSetValue(InputText, ApiResults[i].Embedding);
      Result[UncachedIndices[i]] := ApiResults[i];
    end;
  end;
end;


function GetChunkedEmbeddings(
  const AuthHeader: string;
  const LargeText: string;
  const ChunkSize: Integer;
  const ModelName: string;
  const Config: TAIModelConfig;
  const OverlapSize: Integer = 0
): TArray<TEmbeddingResult>;
var
  Chunks: TArray<string>;
  ChunkCount: Integer;
  StartPos: Integer;
  ChunkText: string;
  StepSize: Integer;
begin
  if ChunkSize <= 0 then
    raise Exception.Create('ChunkSize must be greater than 0');

  if OverlapSize < 0 then
    raise Exception.Create('OverlapSize cannot be negative');

  if OverlapSize >= ChunkSize then
    raise Exception.Create('OverlapSize must be less than ChunkSize');

  StepSize := ChunkSize - OverlapSize;

  // Split text into chunks
  ChunkCount := 0;
  StartPos := 1;

  SetLength(Chunks, (Length(LargeText) div StepSize) + 2);

  while StartPos <= Length(LargeText) do
  begin
    ChunkText := Copy(LargeText, StartPos, ChunkSize);

    if Length(ChunkText) > 0 then
    begin
      Chunks[ChunkCount] := ChunkText;
      Inc(ChunkCount);
    end;

    StartPos := StartPos + StepSize;
  end;

  SetLength(Chunks, ChunkCount);

  // Get embeddings for all chunks
  Result := GetEmbeddings(AuthHeader, Chunks, ModelName, Config, False);
end;


function GetEmbeddingsBatch(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;
  const Config: TAIModelConfig;
  const BatchSize: Integer = 100;
  const OnProgress: TProc<Integer, Integer> = nil
): TArray<TEmbeddingResult>;
var
  i, BatchStart, BatchEnd, CurrentBatch, TotalBatches: Integer;
  BatchInputs: TArray<string>;
  BatchResults: TArray<TEmbeddingResult>;
  ResultIndex: Integer;
begin
  if Length(Inputs) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if BatchSize <= 0 then
    raise Exception.Create('BatchSize must be greater than 0');

  SetLength(Result, Length(Inputs));
  TotalBatches := (Length(Inputs) + BatchSize - 1) div BatchSize;
  ResultIndex := 0;

  for CurrentBatch := 0 to TotalBatches - 1 do
  begin
    BatchStart := CurrentBatch * BatchSize;
    BatchEnd := Min(BatchStart + BatchSize - 1, High(Inputs));

    // Extract batch
    SetLength(BatchInputs, BatchEnd - BatchStart + 1);
    for i := BatchStart to BatchEnd do
      BatchInputs[i - BatchStart] := Inputs[i];

    // Get embeddings for this batch
    BatchResults := GetEmbeddings(AuthHeader, BatchInputs, ModelName, Config, False);

    // Copy to result array
    for i := 0 to High(BatchResults) do
    begin
      Result[ResultIndex] := BatchResults[i];
      Inc(ResultIndex);
    end;

    // Report progress
    if Assigned(OnProgress) then
      OnProgress(CurrentBatch + 1, TotalBatches);
  end;
end;




function GetEmbeddings(
  const AuthHeader: string;
  const Inputs: TArray<string>;
  const ModelName: string;
  const Config: TAIModelConfig;
  const EnableDebug: Boolean = False
): TArray<TEmbeddingResult>;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  URL: string;
  ReqJson: TJSONObject;
  InputArr: TJSONArray;
  i, j: Integer;
  ReqStream: TStringStream;
  RespJson: TJSONValue;
  DataArr: TJSONArray;
  Item: TJSONObject;
  EmbArr: TJSONArray;
  Headers: TNetHeaders;
  RawResp: string;
  EmbIndex: Integer;
begin
  Result := nil;

  if Length(Inputs) = 0 then
    raise Exception.Create('No input texts provided for embeddings');

  // Build URL using Config.BaseURL + Config.EmbeddingsPath [1]
  URL := JoinUrl(Config.BaseURL, Config.EmbeddingsPath);

  // Build OpenAI-compatible JSON body [1]
  ReqJson := TJSONObject.Create;
  try
    ReqJson.AddPair('model', ModelName);

    InputArr := TJSONArray.Create;
    for i := 0 to High(Inputs) do
      InputArr.Add(Inputs[i]);
    ReqJson.AddPair('input', InputArr);

    // encoding_format required for embeddings [1]
    ReqJson.AddPair('encoding_format', 'float');

    ReqStream := TStringStream.Create(ReqJson.ToString, TEncoding.UTF8);
    try
      Http := THTTPClient.Create;
      try
        // Set headers
        SetLength(Headers, 2);
        Headers[0] := TNetHeader.Create('Authorization', AuthHeader);
        Headers[1] := TNetHeader.Create('Content-Type', 'application/json');

        if EnableDebug then
        begin
          Writeln('=== Embeddings Request ===');
          Writeln('URL: ', URL);
          Writeln('Body: ', ReqJson.ToString);
        end;

        // Make POST request
        Resp := Http.Post(URL, ReqStream, nil, Headers);

        RawResp := Resp.ContentAsString;

        if EnableDebug  and Isconsole then
        begin
          Writeln('=== Embeddings Response ===');
          Writeln('Status: ', Resp.StatusCode);
          Writeln('Body: ', RawResp);
        end;

        if Resp.StatusCode <> 200 then
          raise Exception.CreateFmt('Embeddings API error: %d - %s',
            [Resp.StatusCode, RawResp]);

        // Parse response JSON
        RespJson := TJSONObject.ParseJSONValue(RawResp);
        try
          if not Assigned(RespJson) then
            raise Exception.Create('Failed to parse embeddings response JSON');

          DataArr := RespJson.GetValue<TJSONArray>('data');
          if not Assigned(DataArr) then
            raise Exception.Create('No "data" array in embeddings response');

          SetLength(Result, DataArr.Count);

          for i := 0 to DataArr.Count - 1 do
          begin
            Item := DataArr.Items[i] as TJSONObject;

            // Get the index from response
            EmbIndex := Item.GetValue<Integer>('index');
            Result[i].Index := EmbIndex;

            // Store the original input text
            // Match by index to handle potential reordering
            if (EmbIndex >= 0) and (EmbIndex < Length(Inputs)) then
              Result[i].Input := Inputs[EmbIndex]
            else
              Result[i].Input := Inputs[i]; // Fallback to sequential order

            // Parse embedding array
            EmbArr := Item.GetValue<TJSONArray>('embedding');
            if not Assigned(EmbArr) then
              raise Exception.Create('No "embedding" array in data item');

            SetLength(Result[i].Embedding, EmbArr.Count);
            for j := 0 to EmbArr.Count - 1 do
              Result[i].Embedding[j] := EmbArr.Items[j].AsType<Double>;
          end;

        finally
          RespJson.Free;
        end;

      finally
        Http.Free;
      end;
    finally
      ReqStream.Free;
    end;
  finally
    ReqJson.Free;
  end;
end;




end.
