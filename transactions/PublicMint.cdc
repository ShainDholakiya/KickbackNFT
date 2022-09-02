import NonFungibleToken from "../contracts/NonFungibleToken.cdc"
import KickbackNFT from "../contracts/KickbackNFT.cdc"
import MetadataViews from "../contracts/MetadataViews.cdc"

transaction(episodeID: String) {
    let signerCapability: Capability<&KickbackNFT.Collection{KickbackNFT.KickbackNFTCollectionPublic}>
    let ownerCollectionRef: &AnyResource{KickbackNFT.KickbackNFTCollectionPublic}

    prepare(signer: AuthAccount) {
        if signer.borrow<&KickbackNFT.Collection>(from: KickbackNFT.CollectionStoragePath) == nil {
            let collection <- KickbackNFT.createEmptyCollection()
            signer.save(<-collection, to: KickbackNFT.CollectionStoragePath)
            signer.link<&KickbackNFT.Collection{NonFungibleToken.CollectionPublic, KickbackNFT.KickbackNFTCollectionPublic}>(KickbackNFT.CollectionPublicPath, target: KickbackNFT.CollectionStoragePath)
        }

        let owner = getAccount(0x01)
        self.ownerCollectionRef = owner.getCapability(KickbackNFT.CollectionPublicPath)
                                    .borrow<&AnyResource{KickbackNFT.KickbackNFTCollectionPublic}>()
                                    ?? panic("Can't get the User's collection.")
        self.signerCapability = signer.getCapability<&KickbackNFT.Collection{KickbackNFT.KickbackNFTCollectionPublic}>(KickbackNFT.CollectionPublicPath)      
    }

    execute {
        self.ownerCollectionRef.buy(collectionCapability: self.signerCapability, episodeID: episodeID);  
        log("Minted NFT")
    }
}