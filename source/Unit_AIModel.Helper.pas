unit Unit_AIModel.Helper;

interface

 ///
///   very basic test  of access to AI model
///

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.NetEncoding,
  System.JSON;


  function IsAzureBackedModel(const Model: string): Boolean;

  function ModelRequiresDefaultTemperature(const Model: string): Boolean;

  function UseMaxCompletionTokens(const Model: string): Boolean;

  function JoinUrl(const Base, Path: string): string;



implementation


function JoinUrl(const Base, Path: string): string;
begin
  if Base.EndsWith('/') and Path.StartsWith('/') then
    Result := Base + Path.Substring(1)
  else if (not Base.EndsWith('/')) and (not Path.StartsWith('/')) then
    Result := Base + '/' + Path
  else
    Result := Base + Path;
end;





function IsAzureBackedModel(const Model: string): Boolean;
var
  L: string;
begin
  L := Model.ToLower;
  Result := L.StartsWith('gpt-5') or L.StartsWith('gpt-4.1') or
    L.StartsWith('gpt-4o') or L.StartsWith('o3-') or
    L.StartsWith('claudesonnet');
end;

function ModelRequiresDefaultTemperature(const Model: string): Boolean;
begin
  // On this gateway, Azure-backed families often require the default temp only
  Result := IsAzureBackedModel(Model);
end;

function UseMaxCompletionTokens(const Model: string): Boolean;
var
  L: string;
begin
  L := Model.ToLower;
  // Azure-backed models on your gateway that enforce max_completion_tokens
  Result := (L.StartsWith('gpt-5')) or (L.StartsWith('gpt-4.1')) or
    (L.StartsWith('gpt-4o')) or (L.StartsWith('o3-')) or
    (L.StartsWith('claudesonnet'));
end;


end.
