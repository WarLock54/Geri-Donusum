//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;



/* recycle nesnesine tekrardan bak... ve abi ları istersen tekrardan değiştir. */
contract Kasa{
using  SafeMath for uint256;
 Recycle rcy;
    
    address public owner;
    uint256 public recycleCounter;
    uint256 public contributeCounter;
       bool locked;
          
constructor(address adr){
        rcy=Recycle(adr);
        recycleCounter=0;
        contributeCounter=0;
        owner =msg.sender;
    }

    mapping(address =>uint256) public balanceOf;
    mapping(uint256 =>address) public  recycleSahipleri;
    mapping(address =>mapping(uint256 =>bool))public kullaniciGirdiMi;
    mapping(address =>mapping(uint256 =>bool))public contributeKullaniciGirdi;
    mapping(address =>mapping(uint256 =>bool))public contuributeOnay;
    mapping(uint256 => recycle) public recycles;
    mapping(uint256 =>Contribution) public contributions;

///@notice geridönüşüm tipleri ve baslama bitme bilgileri...
enum State{BASLADI,BITTI}
enum RecycleType{PLASTIC,PAPER,GLASS}

///@notice recyle bilgilerimiz...
struct recycle{
    uint256 Id;
    address sahibi;
    string aciklama;
    RecycleType recycletype;
    State state;
    uint256 hedef;
    uint256 deadline;
    uint256 Odul;
    uint256 uretmeZamani;
}
struct Contribution{
    uint256 Id;
    uint256 recycleId;
    address sahibi;
    string aciklama;
    uint256 amount;
    uint256 uretmeZamani;

}

    

    receive() external payable {}
///@notice   belirli isterleri karşılıyor mu onu kontrol etmek amacli kurulan modifierlar....

modifier yenidenGirisEngel(){
    require(!locked);
    locked=true;
    _;
    locked=false;
}
modifier recyleVarMi(uint256 _id)
{
    require(recycleSahipleri[_id]!=address(0),"boyle biri bulunmamaktadir.");
    _;
}
modifier recyleSahibiMi(uint256 _id){
   require(recycleSahipleri[_id]==msg.sender ,"sahibi degil");
    _;
}
modifier yeterliAmount(uint256 _amount){
    require(balanceOf[msg.sender].add(msg.value)>_amount,"yeterli token bulunmamaktadir.");
    _;
}
modifier recyleSureBittiMi(uint256 _id){
require(block.timestamp<=recycles[_id].deadline ,"coktan sureniz doldu");
require(block.timestamp>recycles[_id].deadline ,"recycle sureniz baslamadi");
_;
}
modifier recycleBasladi(uint256 _id){
    require(recycles[_id].state==State.BASLADI,"recycle baslamadi...");
    _;
}
modifier recycleBittidi(uint256 _id){
    require(recycles[_id].state==State.BITTI,"recycle bitmedi...");
    _;
}
modifier kullaniciKatilmadi(uint256 _id){
require(kullaniciGirdiMi[msg.sender][_id]!=true,"kullanici girisi coktan oldu.");
require(kullaniciGirdiMi[msg.sender][_id] != false,
			"kullanici girisi daha olmadi");

_;
}
modifier kullaniciKatkisi(uint256 _id){
    require(contributeKullaniciGirdi[msg.sender][_id]!=true,"kullanici katkisi olmamistir.");
     require(contributeKullaniciGirdi[msg.sender][_id]=true,"kullanici katkisi daha once oldu.");
_;
}
modifier katkiKabulu(address _katkici,uint256 _id){
    require(contuributeOnay[_katkici][_id]!=true,"katki onayi coktan oldu");
     require(contuributeOnay[_katkici][_id]=true,"katki onaylanamadi");
_;
}
///@notice fonksiyonları eventlerle takip etmek için kullandıgım metotlar...
event RecycleTalep(address indexed tokenSahibi,uint256  indexed tokenAmount);
event RecycleOlustur(address indexed recycleSahibi,uint256  indexed recycleid);
event RecycleIptal(uint256 indexed recycleId);
event ContributeOlustur(address indexed contributeSahibi,uint256  indexed recycleid,uint256  indexed contributeId);
event ContributeOnay(uint256 indexed recycleId, uint256 indexed contributeId);
event KullaniciKatilRecycle(address indexed kullanici,uint256 indexed recycleId);
event odulOnay(address indexed kullanici,uint256  recycleId,uint256  contributeId,uint256  amount);



function getRecycleBalance()public view returns (uint256){
    return address(this).balance;
}
///@dev recyle olusturma fonksiyonu...
function createRecycle(
		string memory _aciklama,
		RecycleType _recycleType,
		State _state,
		uint256 _hedef,
		uint256 _deadline,
		uint256 _odul
	) public payable  yeterliAmount(_odul) returns (bool) {
		require(bytes(_aciklama).length > 0, "aciklama recycle tarafindan verilmeli");
		require(
			_recycleType == RecycleType.PLASTIC ||
				_recycleType == RecycleType.PAPER ||
				_recycleType == RecycleType.GLASS,
			"recycle tipleri bunlardan biri olmali"
		);
		require(_hedef > 0, "recycle hedefi vermelisin");
		require(_deadline > 0, "gecerli bir tarih giriniz");
		require(_odul > 0, "gecersiz para miktari girdiniz.");

		
		recycles[recycleCounter] = recycle({
			Id: recycleCounter,
            sahibi: msg.sender,
			aciklama: _aciklama,
			recycletype: _recycleType,
			state: _state,
			hedef: _hedef,
			deadline: block.timestamp + _deadline * 60,
			Odul: _odul,
			uretmeZamani: block.timestamp
		});
		balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
		recycleSahipleri[recycleCounter] = msg.sender;
		recycleCounter++;

		// send eth value to the contract
       bool ok= rcy.transferFrom(msg.sender,address(this),msg.value);
	//	address(this).transfer(msg.value);
    require(ok,"transfer gonderilemedi...");
		emit RecycleOlustur(msg.sender, recycleCounter);
        return ok;
	//	return true;
	}

    ///@dev recycle sona erdirme fonksiyonu

    function recycleIptal(uint256 _id) public recyleSureBittiMi(_id) recyleSahibiMi(_id) recyleVarMi(_id){
        recycle storage RECY=recycles[_id];
        RECY.state=State.BITTI;
        emit RecycleIptal(_id);
    }
    ///@dev recycle bilgilerini goruntülemek
    function GoruntuleRecycle(uint256 id) public view returns(
        uint256 _Id,
        address _sahibi,
    string  memory _aciklama,
    uint _recycletype,
    uint _state,
    uint256 _hedef,
    uint256 _deadline,
    uint256 _Odul,
    uint256 _uretmeZamani
    ){
        _Id=recycles[id].Id;
        _sahibi=recycles[id].sahibi;
        _aciklama=recycles[id].aciklama;
        _recycletype=uint(recycles[id].recycletype);
          _state=uint(recycles[id].state);
          _hedef=recycles[id].hedef;
         _deadline=recycles[id].deadline;
         _Odul=recycles[id].Odul;
         _uretmeZamani=recycles[id].uretmeZamani;

return (_Id,_sahibi,_aciklama,_recycletype,_state,_hedef,_deadline,_Odul,_uretmeZamani);
    }
    ///@dev recycle dizi bilglerini görüntülemek...
    function hepsniGoruntuleRecycle()public view returns(recycle[] memory ){
recycle [] memory  rcylist=new recycle[](recycleCounter);
for(uint i=0;i<recycleCounter;i++){
    recycle storage rcyl=recycles[i];
    rcylist[i]=rcyl;
}
return rcylist;
    }
    function recycleKatil(uint256 _id) public recyleVarMi(_id) kullaniciKatilmadi(_id) recycleBasladi(_id) recyleSureBittiMi(_id){

        kullaniciGirdiMi[msg.sender][_id]=true;
            emit KullaniciKatilRecycle(msg.sender,_id);

    }
    function kullanicikatildiMi(uint _id) public view returns(bool ){
return kullaniciGirdiMi[msg.sender][_id];
    }
    function recycleKatki(uint256 _id,string memory _aciklama,uint256 _amount ) public recyleVarMi(_id) kullaniciKatilmadi(_id) recycleBasladi(_id) recyleSureBittiMi(_id) kullaniciKatkisi(_id)
    returns (bool)
    {
contributions[contributeCounter]= Contribution({
       Id:contributeCounter,
     recycleId:_id,
     sahibi:msg.sender,
     aciklama:_aciklama,
     amount:_amount,
     uretmeZamani:block.timestamp
});
contributeKullaniciGirdi[msg.sender][_id]=true;
contributeCounter++;
emit ContributeOlustur(msg.sender,_id,contributeCounter);
return true;
    }

    function goruntuleContribute(uint _id)public view returns(  uint256 _Id,
    uint256 _recycleId,
    address _sahibi,
    string memory _aciklama,
    uint256 _amount,
    uint256 _uretmeZamani
    ){
        _Id=contributions[_id].Id;
        _recycleId=contributions[_id].recycleId;
        _sahibi=contributions[_id].sahibi;
        _aciklama=contributions[_id].aciklama;
        _amount=contributions[_id].amount;
        _uretmeZamani=contributions[_id].uretmeZamani;

        return(_Id,_recycleId,_sahibi,_aciklama,_amount,_uretmeZamani);
    }

    function hepsniGoruntuleContribute()public view returns(Contribution [] memory ){
Contribution [] memory  contributeslist=new Contribution[](contributeCounter);
for(uint i=0;i<contributeCounter;i++){
    Contribution storage ctbe=contributions[i];
   contributeslist[i]=ctbe;
}
return contributeslist;
    }
    function onaylaContribution(uint256 _recycleId,uint256 _contuributeId) public  katkiKabulu(contributions[_contuributeId].sahibi,_contuributeId) recyleSahibiMi(_recycleId) returns(bool){
contuributeOnay[contributions[contributeCounter].sahibi][_contuributeId]=true;
emit ContributeOnay(_recycleId,_contuributeId);
return true;
    }
    function onaylandiMiContribution(uint _contuributeId)public view returns (bool){
        return contuributeOnay[contributions[contributeCounter].sahibi][_contuributeId];

}
    

    function OdulOnayy(uint256  _recycleId,uint256  _contributeId) public payable yenidenGirisEngel katkiKabulu(contributions[_contributeId].sahibi,_contributeId) recycleBittidi(_recycleId) kullaniciKatkisi(_recycleId) returns (bool){
       
        uint256 hedef=recycles[_recycleId].hedef;
        uint256 odul=recycles[_recycleId].Odul;
        uint256 contributeAmount=contributions[_contributeId].amount;


        uint256 kazanilanOdul=(odul.mul(contributeAmount)).div(hedef);


bool ok= rcy.transferFrom(address(this),msg.sender,kazanilanOdul);
address recycleOlusturan=recycles[_recycleId].sahibi;
balanceOf[recycleOlusturan]=balanceOf[recycleOlusturan].sub(kazanilanOdul);
emit odulOnay( msg.sender, _recycleId, _contributeId,  kazanilanOdul);

return ok;

    }

}
      
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import "./Token.sol";






