program GenLLM;

uses
  System.StartUpCopy,
  FMX.Forms,
  GUI.FMX.Mainform in 'GUI.FMX.Mainform.pas' {FormMain},
  Unit_AIModel.Helper in '..\Unit_AIModel.Helper.pas',
  Unit_AIModel.Probing in '..\Unit_AIModel.Probing.pas',
  Unit_AIModel.TAIModelConfig in '..\Unit_AIModel.TAIModelConfig.pas',
  Unit_AIModel.GetInternalToken in '..\Unit_AIModel.GetInternalToken.pas',
  Unit_AIModel.Embeddings in '..\Unit_AIModel.Embeddings.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
