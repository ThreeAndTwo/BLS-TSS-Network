// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

import "forge-std/Test.sol";
import "../src/libraries/BLS.sol";

contract BLSTest is Test {
    function setUp() public {}

    function testHashToPoint() public {
        uint256[2] memory p = BLS.hashToPoint("hello");

        bool onCurve = BLS.isOnCurveG1([p[0], p[1]]);

        assertTrue(onCurve);
        assertEq(
            p[0],
            8624054983400697718141956802447871958869122227252176640970531463441248681148
        );
        assertEq(
            p[1],
            4714976728303045455220568421558489936628555206298476747206964600484068714510
        );
    }

    function testG2() public {
        uint256 x1 = 17278932652257254326372213117531887034602515361911989965175376143830222599936;
        uint256 y1 = 20031973458929592857375281132123518018056190313544844569373014685916759857230;
        uint256 x2 = 20064204146850969181106739462941001903229194709880588954223883176426803937774;
        uint256 y2 = 14587034285780894150170698790164184681018642187371753355261524461651965258915;

        uint256[4] memory point1 = [x1, x2, y1, y2];
        uint256[4] memory point2 = [x1, x2, BLS.N - y1, BLS.N - y2];
        bool onCurve1 = BLS.isOnCurveG2(point1);
        emit log_uint(onCurve1 ? 1 : 0);
        bool onCurve2 = BLS.isOnCurveG2(point2);
        emit log_uint(onCurve2 ? 1 : 0);
    }

    function testSignatureToUncompressed() public {
        uint256 cx1 = 131449440775817426560367863668973187564446271105289002152564551034334957958;
        uint256 y1 = 5142471158538969335790353460140971440396771055705923842924855903685812733855;

        uint256 cx2 = 2993052591263300251421730215909578160265361713291681977422434783744805156453;
        uint256 y2 = 8236704679255897636411889564940276141365191991937272748153173274454109057806;

        uint256[2] memory uncompressed1 = BLS.signatureToUncompressed(cx1);
        uint256[2] memory uncompressed2 = BLS.signatureToUncompressed(cx2);
        assertEq(uncompressed1[1], y1);
        assertEq(uncompressed2[1], y2);
    }

    function testVerifySignature() public {
        uint256[7] memory params1 = [
            0xde7c516e867a427226866fa41566ad0eb0ff69f54e4408babd2f59c54238fa86,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x116da8c89a0d090f3d8644ada33a5f1c8013ba7204aeca62d66d931b99afe6e7,
            0x12740934ba9615b77b6a49b06fcce83ce90d67b1d0e2a530069e3a7306569a91,
            0x076441042e77b6309644b56251f059cf14befc72ac8a6157d30924e58dc4c172,
            0x25222d9816e5f86b4a7dedd00d04acc5c979c18bd22b834ea8c6d07c0ba441db,
            0x8810fb08e61f12011197f55c2bc5e1e77576ecbf56d73794686e1940e106828e
        ];

        uint256[7] memory params2 = [
            0xde7c516e867a427226866fa41566ad0eb0ff69f54e4408babd2f59c54238fa86,
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x1a507c593ab755ddc738a62bb1edbf00de9d2e0f6829a663c53fa281ca3a296b,
            0x17bfa426fe907fb295063261d2348ad72f3b40c1aaeb8a0e31e29b341d9cc14f,
            0x247fe0adc753328cb9250964f16b77693d273892270be5cfbb4aca3b625606cc,
            0x17e4867e1df6f439500568aaa567952b5c47f3b4eb3a824fcee17000917ce1d0,
            0x2dcb14c407beb29593b6ee1d0db90642f95d23441fe7bb68f195c116563b5882
        ];

        verifySignature(params1);
        verifySignature(params2);
    }

    function verifySignature(uint256[7] memory params) public {
        bytes memory message = abi.encodePacked(params[0], params[1]);
        emit log_bytes(message);
        uint256[2] memory msgPoint = BLS.hashToPoint(message);
        emit log_uint(msgPoint[0]);
        emit log_uint(msgPoint[1]);
        bytes memory publicKey = abi.encodePacked(
            params[2],
            params[3],
            params[4],
            params[5]
        );
        uint256[2] memory sig = BLS.signatureToUncompressed(params[6]);
        emit log_uint(sig[0]);
        emit log_uint(sig[1]);

        bool res = BLS.verifySingle(
            sig,
            BLS.fromBytesPublicKey(publicKey),
            msgPoint
        );

        emit log_uint(res ? 1 : 0);
    }

    // function testPubkeyToUncompressed1() public {
    //     // GroupAffine(x=QuadExtField(Fp256 "(2DE3B4991C30EBB440627686A6795D964A1D01F981B156AB6ECECFA5B94B0478)" + Fp256 "(015DC0177643E0B9B7DC7FCCB6B1712A6F1730D5F7CCD04DCF25B3EDCBEC7A93)" * u), y=QuadExtField(Fp256 "(2F31D29885DD872DF059C8E12FCF9FECD73D71E65EC747FEC843A2C4A8F0C630)" + Fp256 "(0DDBCB3C55C052CF1FD7F54FD9B8A696A2CDA688B05092BF0BCC7D98A6A19F1F)" * u))
    //     // x
    //     // "2de3b4991c30ebb440627686a6795d964a1d01f981b156ab6ececfa5b94b0478" "015dc0177643e0b9b7dc7fccb6b1712a6f1730d5f7ccd04dcf25b3edcbec7a93"
    //     // 20756398912134812078449497828567988906059620378438669533183980259985523934328 617955393439787001855353443017057339186294788049905168865177313479391738515

    //     // y
    //     // "2f31d29885dd872df059c8e12fcf9fecd73d71e65ec747fec843a2c4a8f0c630" "0ddbcb3c55c052cf1fd7f54fd9b8a696a2cda688b05092bf0bcc7d98a6a19f1f"
    //     // 21346732868330046654697465256698294475282421912298539483778111376305406658096 6268409219904789810158462871372220706695311468722235895072814429772529639199

    //     // GroupAffine(x=QuadExtField(Fp256 "(1BBD0871250E76B5EA8E34F6D3F89BDC751AE6EF52DE3C43284C7019295EC379)" + Fp256 "(2CE2C646FE018F13F5E17262C76B6029C6018FE133B722F4A22DBE7735346A04)" * u), y=QuadExtField(Fp256 "(2750392B33CF5F52A1168D2655DAF0B52182AB0B64FC53608B66525C8C41ADD2)" + Fp256 "(2A1B2978C20305B07BBB640A2679F58E40CFF4D94BEADCEE48556AC058FA23D0)" * u))
    //     // x
    //     // "1bbd0871250e76b5ea8e34f6d3f89bdc751ae6ef52de3c43284c7019295ec379" "ace2c646fe018f13f5e17262c76b6029c6018fe133b722f4a22dbe7735346a04"
    //     // 12546439271338559655186752642183721849120899305737352501820067857591789601657 78198485852684628268259372262537068333772691786148832411471909410233205942788

    //     // y
    //     // "2750392b33cf5f52a1168d2655daf0b52182ab0b64fc53608b66525c8c41add2" "2a1b2978c20305b07bbb640a2679f58e40cff4d94beadcee48556ac058fa23d0"
    //     // 17781943424205368556263905344331399021295718771387565154585246754363639180754 19045130738471851014382535487809521049013715510792944134303223009484243346384

    //     uint256 cx1 = 20756398912134812078449497828567988906059620378438669533183980259985523934328;
    //     uint256 cx2 = 617955393439787001855353443017057339186294788049905168865177313479391738515;
    //     uint256 y1 = 21346732868330046654697465256698294475282421912298539483778111376305406658096;
    //     uint256 y2 = 6268409219904789810158462871372220706695311468722235895072814429772529639199;

    //     uint256[2] memory c = [cx1, cx2];
    //     uint256[4] memory uncompressed = BLS.pubkeyToUncompressed(c);
    //     emit log_uint(uncompressed[0]);
    //     emit log_uint(uncompressed[1]);
    //     // assertEq(uncompressed[2], y1);
    //     // assertEq(uncompressed[3], y2);
    // }

    // function testPubkeyToUncompressed2() public {
    //     // GroupAffine(x=QuadExtField(Fp256 "(2DE3B4991C30EBB440627686A6795D964A1D01F981B156AB6ECECFA5B94B0478)" + Fp256 "(015DC0177643E0B9B7DC7FCCB6B1712A6F1730D5F7CCD04DCF25B3EDCBEC7A93)" * u), y=QuadExtField(Fp256 "(2F31D29885DD872DF059C8E12FCF9FECD73D71E65EC747FEC843A2C4A8F0C630)" + Fp256 "(0DDBCB3C55C052CF1FD7F54FD9B8A696A2CDA688B05092BF0BCC7D98A6A19F1F)" * u))
    //     // x
    //     // "2de3b4991c30ebb440627686a6795d964a1d01f981b156ab6ececfa5b94b0478" "015dc0177643e0b9b7dc7fccb6b1712a6f1730d5f7ccd04dcf25b3edcbec7a93"
    //     // 20756398912134812078449497828567988906059620378438669533183980259985523934328 617955393439787001855353443017057339186294788049905168865177313479391738515

    //     // y
    //     // "2f31d29885dd872df059c8e12fcf9fecd73d71e65ec747fec843a2c4a8f0c630" "0ddbcb3c55c052cf1fd7f54fd9b8a696a2cda688b05092bf0bcc7d98a6a19f1f"
    //     // 21346732868330046654697465256698294475282421912298539483778111376305406658096 6268409219904789810158462871372220706695311468722235895072814429772529639199

    //     // GroupAffine(x=QuadExtField(Fp256 "(1BBD0871250E76B5EA8E34F6D3F89BDC751AE6EF52DE3C43284C7019295EC379)" + Fp256 "(2CE2C646FE018F13F5E17262C76B6029C6018FE133B722F4A22DBE7735346A04)" * u), y=QuadExtField(Fp256 "(2750392B33CF5F52A1168D2655DAF0B52182AB0B64FC53608B66525C8C41ADD2)" + Fp256 "(2A1B2978C20305B07BBB640A2679F58E40CFF4D94BEADCEE48556AC058FA23D0)" * u))
    //     // x
    //     // "1bbd0871250e76b5ea8e34f6d3f89bdc751ae6ef52de3c43284c7019295ec379" "ace2c646fe018f13f5e17262c76b6029c6018fe133b722f4a22dbe7735346a04"
    //     // 12546439271338559655186752642183721849120899305737352501820067857591789601657 78198485852684628268259372262537068333772691786148832411471909410233205942788

    //     // y
    //     // "2750392b33cf5f52a1168d2655daf0b52182ab0b64fc53608b66525c8c41add2" "2a1b2978c20305b07bbb640a2679f58e40cff4d94beadcee48556ac058fa23d0"
    //     // 17781943424205368556263905344331399021295718771387565154585246754363639180754 19045130738471851014382535487809521049013715510792944134303223009484243346384

    //     uint256 cx1 = 12546439271338559655186752642183721849120899305737352501820067857591789601657;
    //     uint256 cx2 = 78198485852684628268259372262537068333772691786148832411471909410233205942788;
    //     uint256 y1 = 17781943424205368556263905344331399021295718771387565154585246754363639180754;
    //     uint256 y2 = 19045130738471851014382535487809521049013715510792944134303223009484243346384;

    //     uint256[2] memory c = [cx1, cx2];
    //     uint256[4] memory uncompressed = BLS.pubkeyToUncompressed(c);
    //     // assertTrue(BLS.isValidCompressedPublicKey(c));
    //     assertTrue(BLS.isValidPublicKey(uncompressed));
    //     emit log_uint(uncompressed[0]);
    //     emit log_uint(uncompressed[1]);
    //     // assertEq(uncompressed[2], y1);
    //     // assertEq(uncompressed[3], y2);
    // }
}
