pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// File contracts/NFT.sol

interface IDEBITA {
    function isSenderALoan(address sender) external returns (bool);
    function getAddressById(uint256 id) external view returns (address);
}

contract Ownerships is ERC721Enumerable {
    uint256 id = 0;
    address admin;
    address DebitaContract;
    bool private initialized;

    constructor() ERC721("Debita Ownerships", "") {
        admin = msg.sender;
    }

    modifier onlyContract() {
        require(msg.sender == DebitaContract);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == admin && !initialized);
        _;
    }

    function mint(address to) public onlyContract returns (uint256) {
        id++;
        _mint(to, id);
        return id;
    }

    function setDebitaContract(address newContract) public onlyOwner {
        DebitaContract = newContract;
    }

    function burn(uint256 tokenId) public virtual {
        require(IDEBITA(DebitaContract).isSenderALoan(msg.sender), "Only loans can call this function.");
        _burn(tokenId);
    }

    // building basic svg image
    function buildImage(string memory _type, address loanAddress) internal view returns (string memory) {
        return Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '<svg width="1074" height="1074" viewBox="0 0 1074 1074" fill="none" xmlns="http://www.w3.org/2000/svg"> <path d="M0 0H1074V1074H0V0Z" fill="#212121"/> <path d="M118.153 188H79.4815V78.9091H118.473C129.446 78.9091 138.892 81.093 146.811 85.4609C154.73 89.7933 160.82 96.0256 165.082 104.158C169.379 112.29 171.527 122.02 171.527 133.348C171.527 144.712 169.379 154.477 165.082 162.645C160.82 170.812 154.695 177.08 146.705 181.448C138.75 185.816 129.233 188 118.153 188ZM102.546 168.238H117.195C124.013 168.238 129.748 167.031 134.4 164.616C139.087 162.165 142.603 158.384 144.947 153.27C147.326 148.121 148.516 141.48 148.516 133.348C148.516 125.287 147.326 118.7 144.947 113.586C142.603 108.472 139.105 104.708 134.453 102.293C129.801 99.8786 124.066 98.6712 117.248 98.6712H102.546V168.238ZM225.473 189.598C217.057 189.598 209.813 187.893 203.74 184.484C197.703 181.04 193.051 176.175 189.784 169.889C186.517 163.568 184.884 156.093 184.884 147.464C184.884 139.048 186.517 131.661 189.784 125.305C193.051 118.948 197.65 113.994 203.58 110.443C209.546 106.892 216.542 105.116 224.568 105.116C229.965 105.116 234.99 105.987 239.642 107.727C244.33 109.431 248.414 112.006 251.894 115.45C255.409 118.895 258.144 123.227 260.097 128.447C262.05 133.632 263.026 139.705 263.026 146.665V152.897H193.939V138.835H241.666C241.666 135.567 240.956 132.673 239.536 130.152C238.115 127.631 236.144 125.66 233.623 124.239C231.137 122.783 228.243 122.055 224.941 122.055C221.496 122.055 218.442 122.854 215.779 124.452C213.151 126.015 211.091 128.128 209.6 130.791C208.108 133.419 207.345 136.349 207.309 139.58V152.95C207.309 156.999 208.055 160.496 209.546 163.444C211.073 166.391 213.222 168.664 215.992 170.262C218.762 171.86 222.046 172.659 225.846 172.659C228.367 172.659 230.676 172.304 232.771 171.594C234.866 170.884 236.659 169.818 238.151 168.398C239.642 166.977 240.779 165.237 241.56 163.178L262.547 164.562C261.482 169.605 259.298 174.009 255.995 177.773C252.728 181.501 248.502 184.413 243.318 186.509C238.169 188.568 232.22 189.598 225.473 189.598ZM249.976 78.9091V91.2138H198.094V78.9091H249.976ZM278.261 188V78.9091H300.953V119.925H301.645C302.639 117.723 304.078 115.486 305.96 113.213C307.877 110.905 310.363 108.987 313.417 107.46C316.507 105.898 320.342 105.116 324.923 105.116C330.889 105.116 336.393 106.679 341.436 109.804C346.478 112.893 350.509 117.563 353.527 123.813C356.546 130.028 358.055 137.822 358.055 147.197C358.055 156.324 356.581 164.03 353.634 170.315C350.722 176.565 346.745 181.306 341.702 184.538C336.695 187.734 331.084 189.332 324.869 189.332C320.466 189.332 316.72 188.604 313.63 187.148C310.576 185.692 308.073 183.863 306.119 181.661C304.166 179.424 302.675 177.169 301.645 174.896H300.633V188H278.261ZM300.473 147.091C300.473 151.956 301.148 156.2 302.497 159.822C303.847 163.444 305.8 166.267 308.357 168.291C310.914 170.28 314.021 171.274 317.678 171.274C321.372 171.274 324.497 170.262 327.053 168.238C329.61 166.178 331.546 163.337 332.86 159.715C334.209 156.058 334.884 151.849 334.884 147.091C334.884 142.368 334.227 138.213 332.913 134.626C331.599 131.04 329.664 128.234 327.107 126.21C324.55 124.186 321.407 123.174 317.678 123.174C313.985 123.174 310.86 124.151 308.303 126.104C305.782 128.057 303.847 130.827 302.497 134.413C301.148 138 300.473 142.226 300.473 147.091ZM373.196 188V106.182H395.888V188H373.196ZM384.595 95.6349C381.222 95.6349 378.327 94.5163 375.913 92.2791C373.533 90.0064 372.344 87.2898 372.344 84.1293C372.344 81.0043 373.533 78.3232 375.913 76.0859C378.327 73.8132 381.222 72.6768 384.595 72.6768C387.969 72.6768 390.845 73.8132 393.224 76.0859C395.639 78.3232 396.847 81.0043 396.847 84.1293C396.847 87.2898 395.639 90.0064 393.224 92.2791C390.845 94.5163 387.969 95.6349 384.595 95.6349ZM457.584 106.182V123.227H408.312V106.182H457.584ZM419.498 86.5795H442.19V162.858C442.19 164.953 442.51 166.587 443.149 167.759C443.788 168.895 444.676 169.694 445.812 170.156C446.984 170.617 448.334 170.848 449.861 170.848C450.926 170.848 451.991 170.759 453.057 170.582C454.122 170.369 454.939 170.209 455.507 170.102L459.076 186.988C457.939 187.343 456.341 187.751 454.282 188.213C452.222 188.71 449.719 189.012 446.771 189.119C441.302 189.332 436.508 188.604 432.389 186.935C428.305 185.266 425.127 182.673 422.854 179.158C420.581 175.642 419.463 171.203 419.498 165.841V86.5795ZM495.697 189.545C490.477 189.545 485.825 188.639 481.741 186.828C477.657 184.982 474.426 182.265 472.046 178.678C469.703 175.056 468.531 170.546 468.531 165.148C468.531 160.603 469.365 156.786 471.034 153.696C472.703 150.607 474.976 148.121 477.852 146.239C480.729 144.357 483.996 142.936 487.654 141.977C491.347 141.018 495.218 140.344 499.266 139.953C504.024 139.456 507.86 138.994 510.771 138.568C513.683 138.107 515.796 137.432 517.11 136.544C518.424 135.656 519.081 134.342 519.081 132.602V132.283C519.081 128.909 518.016 126.299 515.885 124.452C513.79 122.606 510.807 121.683 506.936 121.683C502.852 121.683 499.603 122.588 497.188 124.399C494.774 126.175 493.176 128.412 492.394 131.111L471.407 129.406C472.472 124.435 474.568 120.138 477.693 116.516C480.818 112.858 484.848 110.053 489.784 108.099C494.756 106.111 500.509 105.116 507.043 105.116C511.588 105.116 515.938 105.649 520.093 106.714C524.284 107.78 527.994 109.431 531.226 111.668C534.493 113.906 537.068 116.782 538.95 120.298C540.832 123.778 541.773 127.95 541.773 132.815V188H520.253V176.654H519.614C518.3 179.211 516.542 181.466 514.34 183.419C512.139 185.337 509.493 186.846 506.404 187.947C503.314 189.012 499.745 189.545 495.697 189.545ZM502.195 173.884C505.534 173.884 508.481 173.227 511.038 171.913C513.595 170.564 515.601 168.753 517.057 166.48C518.513 164.207 519.241 161.633 519.241 158.756V150.074C518.531 150.536 517.554 150.962 516.311 151.352C515.104 151.707 513.737 152.045 512.21 152.364C510.683 152.648 509.156 152.915 507.629 153.163C506.102 153.376 504.717 153.572 503.474 153.749C500.811 154.14 498.485 154.761 496.496 155.614C494.507 156.466 492.963 157.62 491.862 159.076C490.761 160.496 490.21 162.272 490.21 164.403C490.21 167.492 491.329 169.854 493.566 171.487C495.839 173.085 498.715 173.884 502.195 173.884ZM572.641 189.385C569.126 189.385 566.107 188.142 563.586 185.656C561.1 183.135 559.857 180.116 559.857 176.601C559.857 173.121 561.1 170.138 563.586 167.652C566.107 165.166 569.126 163.923 572.641 163.923C576.05 163.923 579.033 165.166 581.59 167.652C584.147 170.138 585.425 173.121 585.425 176.601C585.425 178.945 584.822 181.093 583.614 183.046C582.442 184.964 580.898 186.509 578.98 187.68C577.062 188.817 574.949 189.385 572.641 189.385Z" fill="url(#paint0_linear_1513_11)"/> <text style="cursor: move;" stroke="#2d2d2d" text-anchor="start"  font-size="30" id="svg_27" y="389.04546" x="75.58673" stroke-width="0" fill="#848484"> Loan Address </text> ',
                        string(
                            abi.encodePacked(
                                '<text style="cursor: move;" stroke="white" text-anchor="start"  font-size="40" font-weight="bold" id="svg_27" y="439.04546" x="95.58673" stroke-width="0" fill="white">',
                                Strings.toHexString(loanAddress),
                                '</text> <text style="cursor: move;" stroke="#2d2d2d" text-anchor="start"  font-size="30" id="svg_27" y="589.04546" x="75.58673" stroke-width="0" fill="#848484"> Type </text> <text style="cursor: move;" stroke="white" text-anchor="start"  font-size="40" id="svg_27" font-weight="bold"  y="639.04546" x="95.58673" stroke-width="0" fill="white">',
                                _type,
                                '</text> <defs> <linearGradient id="paint0_linear_1513_11" x1="94.3557" y1="133" x2="600.412" y2="133" gradientUnits="userSpaceOnUse"> <stop stop-color="#D75071"/> <stop offset="1" stop-color="#705BDC"/> </linearGradient> <linearGradient id="paint1_linear_1513_11" x1="666.562" y1="148" x2="1010.68" y2="148" gradientUnits="userSpaceOnUse"> <stop stop-color="#D75071"/> <stop offset="1" stop-color="#705BDC"/> </linearGradient> </defs> </svg>'
                            )
                        )
                    )
                )
            )
        );
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId <= id, "Token Id does not exist");
        IDEBITA _debita = IDEBITA(DebitaContract);
        address loanAddress = _debita.getAddressById(tokenId);
        string memory _type = tokenId % 2 == 0 ? "Borrower" : "Lender";
        string memory data = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name": "Debita NFT #',
                            Strings.toString(tokenId),
                            '", "description":"',
                            "Own the debt, own the position. Debita Finance NFTs represent the ownership of a loan position on-chain.",
                            '", "external_uri":"',
                            "https://debita.fi/Loan/",
                            Strings.toHexString(loanAddress),
                            '", "image": "',
                            "data:image/svg+xml;base64,",
                            buildImage(_type, loanAddress),
                            '"}'
                        )
                    )
                )
            )
        );
        return data;
    }
}
