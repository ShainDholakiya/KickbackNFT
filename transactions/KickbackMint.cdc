import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import KickbackNFT from "../contracts/KickbackNFT.cdc"

transaction(name: String, description: String, thumbnail: String, episodeID: String, podcastID: String, metadata: {String: String}) {
    let minter: &KickbackNFT.NFTMinter
        
    prepare(signer: AuthAccount) {  
        if signer.borrow<&KickbackNFT.Collection>(from: KickbackNFT.CollectionStoragePath) == nil {
            let collection <- KickbackNFT.createEmptyCollection()
            signer.save(<-collection, to: KickbackNFT.CollectionStoragePath)
            signer.link<&KickbackNFT.Collection{NonFungibleToken.CollectionPublic, KickbackNFT.KickbackNFTCollectionPublic}>(KickbackNFT.CollectionPublicPath, target: KickbackNFT.CollectionStoragePath)
        }
        self.minter = signer.borrow<&KickbackNFT.NFTMinter>(from: KickbackNFT.MinterStoragePath)
                        ?? panic("Could not borrow a reference to the NFT minter")
    }
    
    execute {
        self.minter.mintNFT(
            name: name,
            description: description,
            thumbnail: thumbnail,
            episodeID: episodeID,
            podcastID: podcastID,
            metadata: metadata
        )
        log("Minted an NFT")
    }
}