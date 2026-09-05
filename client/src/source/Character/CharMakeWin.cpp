#include "stdafx.h"
#include "Character/CSItemSet.h"
#include "Character/CSParts.h"
#include "Character/CSTeam.h"
#include "Character/CharMakeWin.h"
#include "Character/CharacterManager.h"
#include "Character/ZzzBMD.h"
#include "Character/ZzzCharacter.h"
#include "Character/ZzzObject.h"
#include "Guild/UIGuildInfo.h"
#include "Input/Input.h"
#include "Network/Server/ZzzInfomation.h"
#include "Render/ZzzInterface.h"
#include "Render/ZzzOpenglUtil.h"
#include "Render/ZzzTexture.h"
#include "UI/Legacy/UIControls.h"
#include "UI/Legacy/UIWindows.h"
#include "UI/Legacy/ZzzInventory.h"
#include "Dotnet/PacketFunctions_ClientToServer.h"

#define CMW_OK		0
#define CMW_CANCEL	1

using namespace SEASON3B;

CCharMakeWin::CCharMakeWin()
{
}

CCharMakeWin::~CCharMakeWin()
{
}

void CCharMakeWin::Init()
{
	CWin::Init();
	CWin::SetSize(190, 250);

	m_nSelJob = 0;
	m_nSelStat = 0;

	for (int i = 0; i < MAX_CLASS; ++i)
	{
		m_bSelect[i] = false;
	}

	memset(&CharacterView, 0, sizeof(CHARACTER));
	CharacterView.Class = 0;
	CharacterView.Skin = 0;

	InputEnable = false;
	ClearInput(FALSE);
	InputTextWidth = 90;
	InputNumber = 1;
	InputTextMax[0] = MAX_ID_SIZE;

	m_asprBack[0].Create(190, 250, 0, 0, true);
	m_asprBack[0].SetPosition(0, 0);

	m_asprBack[1].Create(170, 110, 0, 0, true);
	m_asprBack[1].SetPosition(10, 30);

	for (int i = 0; i < MAX_CLASS; ++i)
	{
		m_btnJob[i].Create(40, 40, BITMAP_INTERFACE_EX + 1, 0, 0, 0, 1, 0, 1, 1, true);
		m_btnJob[i].SetPosition(15 + (i % 4) * 42, 35 + (i / 4) * 42);
	}

	m_btnStat[0].Create(80, 20, BITMAP_INTERFACE_EX + 2, 0, 0, 0, 1, 0, 1, 1, true);
	m_btnStat[0].SetPosition(15, 145);
	m_btnStat[1].Create(80, 20, BITMAP_INTERFACE_EX + 2, 0, 0, 0, 1, 0, 1, 1, true);
	m_btnStat[1].SetPosition(95, 145);

	m_btnOK.Create(60, 24, BITMAP_INTERFACE_EX + 3, 0, 0, 0, 1, 0, 1, 1, true);
	m_btnOK.SetPosition(30, 210);
	m_btnCancel.Create(60, 24, BITMAP_INTERFACE_EX + 3, 0, 0, 0, 1, 0, 1, 1, true);
	m_btnCancel.SetPosition(100, 210);

	RegisterButton(&m_btnOK);
	RegisterButton(&m_btnCancel);
	for (int i = 0; i < MAX_CLASS; ++i)
		RegisterButton(&m_btnJob[i]);
	RegisterButton(&m_btnStat[0]);
	RegisterButton(&m_btnStat[1]);
}

void CCharMakeWin::Create()
{
	Init();
	CWin::Create();
}

void CCharMakeWin::Release()
{
	CWin::Release();
}

void CCharMakeWin::SetPosition(int nXCoord, int nYCoord)
{
	CWin::SetPosition(nXCoord, nYCoord);
}

void CCharMakeWin::Show(bool bShow)
{
	CWin::Show(bShow);
	if (bShow)
	{
		InputEnable = true;
		ClearInput(FALSE);
	}
	else
	{
		InputEnable = false;
	}
}

bool CCharMakeWin::CursorInWin(int nArea)
{
	return CWin::CursorInWin(nArea);
}

void CCharMakeWin::UpdateWhileActive(double dDeltaTick)
{
	CWin::UpdateWhileActive(dDeltaTick);
}

void CCharMakeWin::UpdateWhileShow(double dDeltaTick)
{
	CWin::UpdateWhileShow(dDeltaTick);
}

void CCharMakeWin::RenderControls()
{
	RenderCreateCharacter();
	::EnableAlphaTest();

	for (auto& sprite : m_asprBack)
	{
		sprite.Render();
	}
	CWin::RenderButtons();
	g_pRenderText->SetFont(g_hFixFont);
	g_pRenderText->SetTextColor(CLRDW_WHITE);
}

void CCharMakeWin::RenderCreateCharacter()
{
}

void CCharMakeWin::UpdateDisplay()
{
}

void CCharMakeWin::RequestCreateCharacter()
{
	constexpr size_t kMinCharacterNameLength = 4;
	const std::wstring characterName = InputText[0];

	// todo: check with regex from server
	if (characterName.length() < kMinCharacterNameLength)
		rUIMng.PopUpMsgWin(MESSAGE_MIN_LENGTH);
	else if (::CheckName())
		rUIMng.PopUpMsgWin(MESSAGE_ID_SPACE_ERROR);
	else if (CheckSpecialText(InputText[0]))
		rUIMng.PopUpMsgWin(MESSAGE_SPECIAL_NAME);
	else
	{
		const auto classByte = static_cast<CharacterClassNumber>((CharacterView.Class << 2) + CharacterView.Skin);
		CurrentProtocolState = REQUEST_CREATE_CHARACTER;
		SocketClient->ToGameServer()->SendCreateCharacter(MU_C16(InputText[0]), classByte);
		//SendRequestCreateCharacter(InputText[0], CharacterView.Class, CharacterView.Skin);
		rUIMng.HideWin(this);
		rUIMng.PopUpMsgWin(MESSAGE_WAIT);
	}
}

void CCharMakeWin::Update()
{
	CWin::Update();
}
