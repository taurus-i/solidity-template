// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IERC5169.sol";

interface IExtension {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

contract StoryNFT is IERC5169, ERC721Enumerable, ERC2981, Ownable2Step, ReentrancyGuard {
    string private description;

    string[] private tokenScriptURI;

    string public uriOrJson;

    address public factory;

    address public extension;

    address public minter;

    uint256 public maxSupply;

    uint256 public counter;

    string public sharedImage;

    event MinterUpdated(address _minter);

    event ExtensionUpdated(address _extension);

    event ContractURIUpdated();

    /// @dev This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    event MintDetails(address sender, address origin, uint256 tokenId);

    constructor(
        address _owner,
        uint256 max_supply,
        string memory _name,
        string memory _symbol,
        string memory _description
    ) ERC721(_name, _symbol) Ownable(_owner) {
        factory = msg.sender;
        maxSupply = max_supply;
        description = _description;
        minter = _owner;
    }

    function scriptURI() public view override returns (string[] memory) {
        return tokenScriptURI;
    }

    function setScriptURI(string[] memory newScriptURI) public onlyOwner {
        tokenScriptURI = newScriptURI;

        emit ScriptUpdate(newScriptURI);
    }

    function emitERC4906Event(uint256 _fromTokenId, uint256 _toTokenId) external {
        require(msg.sender == extension, "Not granted");

        if (_fromTokenId == _toTokenId) {
            emit MetadataUpdate(_fromTokenId);
        } else {
            emit BatchMetadataUpdate(_fromTokenId, _toTokenId);
        }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        if (extension != address(0)) {
            return IExtension(extension).tokenURI(tokenId);
        }

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    abi.encodePacked(
                        "{",
                        '"name":"',
                        name(),
                        " #",
                        toString(tokenId),
                        '",',
                        '"description":"',
                        description,
                        '",',
                        '"image":"',
                        sharedImage,
                        '"',
                        "}"
                    )
                )
            )
        );
    }

    function burn(uint256 tokenId) external {
        require(msg.sender == ownerOf(tokenId), "Not granted");
        _burn(tokenId);
    }

    function setExtension(address _contract) external onlyOwner {
        require(_contract != address(0), "Zero address");
        extension = _contract;
        emit ExtensionUpdated(_contract);
    }

    function setSharedImage(string calldata image) external onlyOwner {
        sharedImage = image;
    }

    // https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return uriOrJson;
    }

    // https://docs.opensea.io/docs/contract-level-metadata
    function setContractURI(string calldata _uri_or_json) external onlyOwner {
        uriOrJson = _uri_or_json;
        emit ContractURIUpdated();
    }

    function deleteDefaultRoyalty() external onlyOwner {
        ERC2981._deleteDefaultRoyalty();
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        ERC2981._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        ERC2981._resetTokenRoyalty(tokenId);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        ERC2981._setDefaultRoyalty(receiver, feeNumerator);
    }

    // ERC 173 4096 2981 5169
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC2981)
        returns (bool)
    {
        return interfaceId == bytes4(0x7f5828d0) || interfaceId == bytes4(0x49064906)
            || interfaceId == type(IERC5169).interfaceId || interfaceId == type(IERC2981).interfaceId
            || super.supportsInterface(interfaceId);
    }

    bytes16 private constant HEX_DIGITS = "0123456789abcdef";

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Zero address");
        minter = _minter;
        emit MinterUpdated(_minter);
    }

    function batchMintForOne(address to, uint16 amount) public nonReentrant {
        require(msg.sender == minter, "Not Granted");
        require(maxSupply == 0 || counter + amount <= maxSupply, "Over MAX");

        uint256 currentTokenId = counter;
        for (uint256 i = 0; i < amount; i++) {
            currentTokenId++;
            _mint(to, currentTokenId);
        }
        counter = currentTokenId;
    }

    function batchMintForMultiple(address[] calldata toList, uint16 amount) public nonReentrant {
        require(msg.sender == minter, "Not Granted");
        require(maxSupply == 0 || counter + amount <= maxSupply, "Over MAX");

        uint256 currentTokenId = counter;
        for (uint256 i = 0; i < amount; i++) {
            require(toList[i] != address(0), "Zero address");
            currentTokenId++;
            _mint(toList[i], currentTokenId);
        }
        counter = currentTokenId;
    }
}
