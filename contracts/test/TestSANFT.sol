import "../SANFT.sol";

contract TestSANFT is SANFT {
  constructor() SANFT(address(0), 0) {}
  function testCleanEmptySA() external virtual  {
    console.log("Start");
    SA storage sa = _sas[0];
    _mint(msg.sender, 0);
    SubSA memory empty = SubSA({sale: address(0), remainingAmount: 0, vestedPercentage:100});
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    assert(ownerOf(0) == msg.sender);
    assert(!cleanEmptySA(sa, 0, 4));
    assert(!_exists(0));

    // new array route
    SubSA memory something  = SubSA({sale: address(0), remainingAmount: 10, vestedPercentage:90});
    _mint(msg.sender, 0);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(something);
    sa.subSAs.push(something);
    sa.subSAs.push(something);
    assert(ownerOf(0) == msg.sender);
    assert(cleanEmptySA(sa, 0, 4));
    assert(_sas[0].subSAs.length == 3);

    // the shift route
    sa.subSAs.push(something);
    sa.subSAs.push(something);
    sa.subSAs.push(something);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    sa.subSAs.push(empty);
    assert(cleanEmptySA(sa, 0, 3));
    assert(_sas[0].subSAs.length == 6);
  }
}